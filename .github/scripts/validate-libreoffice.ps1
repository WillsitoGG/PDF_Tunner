[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedMsiSha256,

    [string]$BackendLogRoot,

    [switch]$RequireBackendProbe,

    [switch]$RequireRelocation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "Not a valid PE/MZ executable: $Path"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length) {
        throw "Invalid PE header offset in $Path"
    }
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or $bytes[$peOffset + 2] -ne 0 -or $bytes[$peOffset + 3] -ne 0) {
        throw "Missing PE signature in $Path"
    }
    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

function Get-KeyValueMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)
    $result = @{}
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        if ($line -match '^([^=]+)=(.*)$') {
            $result[$Matches[1]] = $Matches[2]
        }
    }
    return $result
}

function Assert-PdfSignature {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $expected = [byte[]](0x25,0x50,0x44,0x46,0x2D)
        $actual = New-Object byte[] $expected.Length
        $read = $stream.Read($actual, 0, $actual.Length)
        if ($read -ne $expected.Length) { throw "PDF is too short: $Path" }
        for ($i = 0; $i -lt $expected.Length; $i++) {
            if ($actual[$i] -ne $expected[$i]) { throw "Output is not a PDF: $Path" }
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-PackageMetadata {
    param([Parameter(Mandatory = $true)][string]$Root)

    $tools = Join-Path $Root 'tools'
    $office = Join-Path $tools 'libreoffice'
    $canonical = Join-Path $office 'program\soffice.exe'
    $sofficeBin = Join-Path $office 'program\soffice.bin'
    $versionIni = Join-Path $office 'program\version.ini'
    $shim = Join-Path $tools 'bin\soffice.exe'
    $versionFile = Join-Path $office 'version.txt'
    $provenance = Join-Path $office 'PROVENANCE.txt'
    $shaFile = Join-Path $office 'SHA256SUMS.txt'

    foreach ($path in @($canonical, $sofficeBin, $versionIni, $shim, $versionFile, $provenance, $shaFile)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required LibreOffice portable file is missing: $path"
        }
    }

    if ((Get-PeMachine -Path $canonical) -ne 0x8664) {
        throw 'Canonical LibreOffice soffice.exe is not an AMD64 PE executable.'
    }
    if ((Get-PeMachine -Path $shim) -ne 0x8664) {
        throw 'PDF_Tunner soffice launcher is not an AMD64 PE executable.'
    }

    $recordedVersion = (Get-Content -LiteralPath $versionFile -Raw).Trim()
    if ($recordedVersion -ne $Version) {
        throw "LibreOffice version.txt mismatch: expected $Version, got '$recordedVersion'."
    }

    $metadata = Get-KeyValueMetadata -Path $provenance
    $expected = @{
        'NAME' = 'LibreOffice'
        'VERSION' = $Version
        'ARCHITECTURE' = 'x64'
        'PACKAGE_VARIANT' = 'official-windows-x86-64-msi-administrative-image'
        'MSI_SHA256' = $ExpectedMsiSha256.ToLowerInvariant()
        'CANONICAL_EXE' = 'program/soffice.exe'
        'STIRLING_PROBE' = 'soffice'
        'STIRLING_SHIM' = '../bin/soffice.exe'
        'STIRLING_SHIM_MODE' = 'native-relative-launcher'
    }
    foreach ($key in $expected.Keys) {
        if (-not $metadata.ContainsKey($key)) { throw "LibreOffice provenance is missing $key." }
        if ($metadata[$key].ToLowerInvariant() -ne $expected[$key].ToLowerInvariant()) {
            throw "LibreOffice provenance mismatch for ${key}: expected '$($expected[$key])', got '$($metadata[$key])'."
        }
    }

    $hashExpectations = [ordered]@{
        'program/soffice.exe' = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
        'program/soffice.bin' = (Get-FileHash -LiteralPath $sofficeBin -Algorithm SHA256).Hash.ToLowerInvariant()
        'program/version.ini' = (Get-FileHash -LiteralPath $versionIni -Algorithm SHA256).Hash.ToLowerInvariant()
        '../bin/soffice.exe' = (Get-FileHash -LiteralPath $shim -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $shaText = Get-Content -LiteralPath $shaFile -Raw
    foreach ($entry in $hashExpectations.GetEnumerator()) {
        $escapedPath = [Regex]::Escape($entry.Key)
        if ($shaText -notmatch "(?im)^$($entry.Value)\s+$escapedPath\s*$") {
            throw "LibreOffice SHA256SUMS.txt is missing or mismatches $($entry.Key)."
        }
    }

    $leakedMsi = @(Get-ChildItem -LiteralPath $office -Recurse -Force -File -Filter '*.msi' -ErrorAction SilentlyContinue)
    if ($leakedMsi.Count -gt 0) {
        throw 'LibreOffice source MSI is present inside the portable package.'
    }
}

function Invoke-LibreOfficeFunctionalCheck {
    param([Parameter(Mandatory = $true)][string]$Root)

    $tools = Join-Path $Root 'tools'
    $binRoot = Join-Path $tools 'bin'
    $programRoot = Join-Path $tools 'libreoffice\program'
    $shim = Join-Path $binRoot 'soffice.exe'
    $expectedTemp = Join-Path $Root 'data\tmp\libreoffice'
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'data\tmp') | Out-Null

    $work = Join-Path $Root ('data\tmp\libreoffice-validation-' + [Guid]::NewGuid().ToString('N'))
    $profile = Join-Path $work 'profile'
    New-Item -ItemType Directory -Force -Path $profile | Out-Null
    $html = Join-Path $work 'input.html'
    $pdf = Join-Path $work 'input.pdf'
    Set-Content -LiteralPath $html -Encoding utf8 -Value '<!doctype html><html><body><h1>PDF_Tunner LibreOffice validation</h1><p>Portable Office to PDF conversion.</p></body></html>'
    $profileUri = ([Uri](Get-Item -LiteralPath $profile).FullName).AbsoluteUri

    $hostProfile = Join-Path $env:APPDATA 'LibreOffice'
    $hostProfileExisted = Test-Path -LiteralPath $hostProfile
    $oldPath = $env:PATH
    try {
        $system32 = Join-Path $env:SystemRoot 'System32'
        $env:PATH = "$binRoot;$programRoot;$system32;$env:SystemRoot"

        $resolvedLines = @(& where.exe soffice 2>&1)
        if ($LASTEXITCODE -ne 0 -or $resolvedLines.Count -eq 0) {
            throw 'where.exe soffice did not resolve the package-local launcher.'
        }
        $resolved = [System.IO.Path]::GetFullPath(($resolvedLines[0] | Out-String).Trim())
        if ($resolved -ne [System.IO.Path]::GetFullPath($shim)) {
            throw "Isolated PATH resolved soffice outside PDF_Tunner: $resolved"
        }

        $reported = (& soffice --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "Packaged soffice --version failed with exit code $LASTEXITCODE."
        }
        if ($reported -notmatch ('(?i)\b' + [Regex]::Escape($Version) + '\b')) {
            throw "LibreOffice reported unexpected version. Expected $Version, got '$reported'."
        }

        & soffice "-env:UserInstallation=$profileUri" --headless --nologo --convert-to pdf --outdir $work $html 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Package-local LibreOffice conversion failed with exit code $LASTEXITCODE."
        }
        if (-not (Test-Path -LiteralPath $pdf -PathType Leaf)) {
            throw 'LibreOffice did not create the expected PDF.'
        }
        if ((Get-Item -LiteralPath $pdf).Length -le 0) {
            throw 'LibreOffice created an empty PDF.'
        }
        Assert-PdfSignature -Path $pdf

        if (-not (Test-Path -LiteralPath $expectedTemp -PathType Container)) {
            throw "PDF_Tunner soffice launcher did not create its package-local TEMP/TMP directory: $expectedTemp"
        }
        if (-not $hostProfileExisted -and (Test-Path -LiteralPath $hostProfile)) {
            throw "LibreOffice created a host Roaming AppData profile despite explicit portable profile: $hostProfile"
        }

        Start-Sleep -Milliseconds 500
        $escapedRoot = [Regex]::Escape($Root)
        $leftovers = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.CommandLine -and $_.CommandLine -match $escapedRoot -and $_.Name -match '(?i)^soffice(\.bin|\.exe)?$'
        })
        if ($leftovers.Count -gt 0) {
            $leftovers | Select-Object ProcessId, Name, CommandLine | Format-List
            throw 'LibreOffice left package-local soffice processes running after conversion.'
        }

        Write-Host "PASS functional LibreOffice check at: $Root"
    }
    finally {
        $env:PATH = $oldPath
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
Assert-PackageMetadata -Root $portable
Invoke-LibreOfficeFunctionalCheck -Root $portable

if ($RequireRelocation) {
    $parent = Split-Path -Path $portable -Parent
    $relocated = Join-Path $parent 'PDF_Tunner LibreOffice relocated proof'
    Remove-Item -LiteralPath $relocated -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $portable -Destination $relocated
    try {
        $relocatedRoot = (Resolve-Path -LiteralPath $relocated).Path
        Assert-PackageMetadata -Root $relocatedRoot
        Invoke-LibreOfficeFunctionalCheck -Root $relocatedRoot
    }
    finally {
        if (Test-Path -LiteralPath $relocated -PathType Container) {
            Move-Item -LiteralPath $relocated -Destination $portable
        }
    }
}

if ($RequireBackendProbe) {
    if ([string]::IsNullOrWhiteSpace($BackendLogRoot)) {
        throw 'RequireBackendProbe requires BackendLogRoot.'
    }
    if (-not (Test-Path -LiteralPath $BackendLogRoot -PathType Container)) {
        throw "Backend log root does not exist: $BackendLogRoot"
    }
    $logs = @(Get-ChildItem -LiteralPath $BackendLogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
    if ($logs.Count -eq 0) { throw "No backend logs were found under $BackendLogRoot." }
    $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
    if ($logText -match '(?im)Missing dependency:\s*soffice\b') {
        throw 'Stirling runtime dependency checker reported Missing dependency: soffice.'
    }
    if ($logText -match '(?im)Disabling group:\s*LibreOffice\b') {
        throw 'Stirling runtime dependency checker disabled the LibreOffice group.'
    }
    Write-Host 'Stirling backend logs accept the package-local LibreOffice soffice dependency.'
}

Write-Host "PASS: packaged LibreOffice $Version is AMD64, hash/provenance verified, resolves through the native PDF_Tunner launcher, converts HTML -> PDF with package-local TEMP/TMP/profile state, and relocates successfully when requested."
