[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedInstallerSha256,

    [string]$BackendLogRoot,

    [switch]$RequireBackendProbe
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
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or $bytes[$peOffset + 2] -ne 0x00 -or $bytes[$peOffset + 3] -ne 0x00) {
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

function Assert-BinarySignature {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Expected
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $actual = New-Object byte[] $Expected.Length
        $read = $stream.Read($actual, 0, $actual.Length)
        if ($read -ne $Expected.Length) {
            throw "File is too short for expected signature: $Path"
        }
        for ($i = 0; $i -lt $Expected.Length; $i++) {
            if ($actual[$i] -ne $Expected[$i]) {
                throw "Unexpected file signature at byte $i for $Path"
            }
        }
    }
    finally {
        $stream.Dispose()
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$ghostscriptRoot = Join-Path $portable 'tools\ghostscript'
$binRoot = Join-Path $ghostscriptRoot 'bin'
$canonical = Join-Path $binRoot 'gswin64c.exe'
$alias = Join-Path $binRoot 'gs.exe'
$versionFile = Join-Path $ghostscriptRoot 'version.txt'
$provenanceFile = Join-Path $ghostscriptRoot 'PROVENANCE.txt'
$shaFile = Join-Path $ghostscriptRoot 'SHA256SUMS.txt'

foreach ($path in @($canonical, $alias, $versionFile, $provenanceFile, $shaFile)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Ghostscript package file is missing: $path"
    }
}

$recordedVersion = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($recordedVersion -ne $Version) {
    throw "Ghostscript version.txt mismatch: expected $Version, got '$recordedVersion'."
}

$metadata = Get-KeyValueMetadata -Path $provenanceFile
$requiredMetadata = @{
    'NAME' = 'Ghostscript'
    'VERSION' = $Version
    'PACKAGE_VARIANT' = 'official-win64-nsis'
    'INSTALLER_SHA256' = $ExpectedInstallerSha256.ToLowerInvariant()
    'CANONICAL_EXE' = 'bin/gswin64c.exe'
    'STIRLING_ALIAS' = 'bin/gs.exe'
    'STIRLING_ALIAS_MODE' = 'byte-identical-copy'
}
foreach ($key in $requiredMetadata.Keys) {
    if (-not $metadata.ContainsKey($key)) {
        throw "Ghostscript provenance is missing $key."
    }
    if ($metadata[$key].ToLowerInvariant() -ne $requiredMetadata[$key].ToLowerInvariant()) {
        throw "Ghostscript provenance mismatch for ${key}: expected '$($requiredMetadata[$key])', got '$($metadata[$key])'."
    }
}

$canonicalMachine = Get-PeMachine -Path $canonical
$aliasMachine = Get-PeMachine -Path $alias
if ($canonicalMachine -ne 0x8664 -or $aliasMachine -ne 0x8664) {
    throw ('Ghostscript executables are not AMD64 PE binaries: canonical=0x{0:X4}, alias=0x{1:X4}' -f $canonicalMachine, $aliasMachine)
}

$canonicalHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
$aliasHash = (Get-FileHash -LiteralPath $alias -Algorithm SHA256).Hash.ToLowerInvariant()
if ($canonicalHash -ne $aliasHash) {
    throw 'Packaged gs.exe alias is not byte-identical to official gswin64c.exe.'
}

$shaText = Get-Content -LiteralPath $shaFile -Raw
if ($shaText -notmatch "(?im)^$canonicalHash\s+bin/gswin64c\.exe\s*$") {
    throw 'Ghostscript SHA256SUMS.txt does not contain the canonical executable hash.'
}
if ($shaText -notmatch "(?im)^$aliasHash\s+bin/gs\.exe\s*$") {
    throw 'Ghostscript SHA256SUMS.txt does not contain the Stirling alias hash.'
}

$leakedInstallers = @(Get-ChildItem -LiteralPath $ghostscriptRoot -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq 'ghostscript-win64.exe' -or $_.Name -match '^gs\d+w64\.exe$' })
if ($leakedInstallers.Count -gt 0) {
    $leakedInstallers | Select-Object FullName, Length | Format-Table -AutoSize
    throw 'Downloaded Ghostscript installer is present inside the portable product tree.'
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-ghostscript-validation-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$ps = Join-Path $tempRoot 'input.ps'
$pdf = Join-Path $tempRoot 'output.pdf'
$png = Join-Path $tempRoot 'output.png'

$oldPath = $env:PATH
$oldGsLib = $env:GS_LIB
$oldGsDll = $env:GS_DLL
$oldGsOptions = $env:GS_OPTIONS
try {
    $system32 = Join-Path $env:SystemRoot 'System32'
    $env:PATH = "$binRoot;$system32;$env:SystemRoot"
    Remove-Item Env:GS_LIB -ErrorAction SilentlyContinue
    Remove-Item Env:GS_DLL -ErrorAction SilentlyContinue
    Remove-Item Env:GS_OPTIONS -ErrorAction SilentlyContinue

    $whereOutput = @(& where.exe gs 2>&1)
    if ($LASTEXITCODE -ne 0 -or $whereOutput.Count -eq 0) {
        throw 'where.exe gs did not resolve the packaged Stirling Ghostscript alias.'
    }
    $resolved = [System.IO.Path]::GetFullPath(($whereOutput[0] | Out-String).Trim())
    if ($resolved -ne [System.IO.Path]::GetFullPath($alias)) {
        throw "Isolated PATH resolved gs outside the portable package: $resolved"
    }

    $reportedVersion = (& gs --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged gs --version failed with exit code $LASTEXITCODE."
    }
    if ($reportedVersion -ne $Version) {
        throw "Packaged gs version mismatch: expected $Version, got '$reportedVersion'."
    }

    Set-Content -LiteralPath $ps -Encoding ascii -Value @(
        '%!PS-Adobe-3.0',
        '/Courier findfont 18 scalefont setfont',
        '72 720 moveto',
        '(PDF_Tunner Ghostscript validation) show',
        'showpage'
    )

    & gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=pdfwrite "-sOutputFile=$pdf" $ps 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged Ghostscript PostScript-to-PDF operation failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $pdf -PathType Leaf)) {
        throw 'Ghostscript did not create the expected PDF output.'
    }
    Assert-BinarySignature -Path $pdf -Expected ([byte[]](0x25,0x50,0x44,0x46,0x2D))

    & gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=png16m -r72 "-sOutputFile=$png" $pdf 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged Ghostscript PDF-to-PNG operation failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $png -PathType Leaf)) {
        throw 'Ghostscript did not create the expected PNG output.'
    }
    Assert-BinarySignature -Path $png -Expected ([byte[]](0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A))
}
finally {
    $env:PATH = $oldPath
    if ($null -eq $oldGsLib) { Remove-Item Env:GS_LIB -ErrorAction SilentlyContinue } else { $env:GS_LIB = $oldGsLib }
    if ($null -eq $oldGsDll) { Remove-Item Env:GS_DLL -ErrorAction SilentlyContinue } else { $env:GS_DLL = $oldGsDll }
    if ($null -eq $oldGsOptions) { Remove-Item Env:GS_OPTIONS -ErrorAction SilentlyContinue } else { $env:GS_OPTIONS = $oldGsOptions }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($RequireBackendProbe) {
    if ([string]::IsNullOrWhiteSpace($BackendLogRoot)) {
        throw 'RequireBackendProbe requires BackendLogRoot.'
    }
    if (-not (Test-Path -LiteralPath $BackendLogRoot -PathType Container)) {
        throw "Backend log root does not exist: $BackendLogRoot"
    }

    $logs = @(Get-ChildItem -LiteralPath $BackendLogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
    if ($logs.Count -eq 0) {
        throw "No backend logs were found under $BackendLogRoot."
    }
    $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
    if ($logText -match '(?im)Missing dependency:\s*gs\b') {
        throw 'Stirling runtime dependency checker reported Missing dependency: gs.'
    }
    Write-Host 'Stirling backend logs do not report the Ghostscript gs dependency as missing.'
}

Write-Host "PASS: packaged Ghostscript $Version is AMD64, provenance/hash verified, resolves as package-local gs, and completed PostScript -> PDF -> PNG functional validation."
