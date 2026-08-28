[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$DownloadUrl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedSha256,

    [Parameter(Mandatory = $true)]
    [string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = [System.IO.Path]::GetFullPath($PortableRoot)
if (-not (Test-Path -LiteralPath $portable -PathType Container)) {
    throw "Portable root does not exist: $portable"
}

$toolsRoot = Join-Path $portable 'tools'
$toolRoot = Join-Path $toolsRoot 'libreoffice'
$binRoot = Join-Path $toolsRoot 'bin'
$shim = Join-Path $binRoot 'soffice.exe'
Remove-Item -LiteralPath $toolRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
New-Item -ItemType Directory -Force -Path $binRoot | Out-Null
Remove-Item -LiteralPath $shim -Force -ErrorAction SilentlyContinue

$launcher = (Resolve-Path -LiteralPath $LauncherSource).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-libreoffice-stage-" + [Guid]::NewGuid().ToString('N'))
$msiPath = Join-Path $tempRoot 'LibreOffice-Win-x86-64.msi'
$adminRoot = Join-Path $tempRoot 'administrative-image'
New-Item -ItemType Directory -Force -Path $adminRoot | Out-Null

try {
    Write-Host "Downloading official LibreOffice $Version x64 MSI..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $msiPath -UseBasicParsing

    $actualSha = (Get-FileHash -LiteralPath $msiPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedSha = $ExpectedSha256.ToLowerInvariant()
    if ($actualSha -ne $expectedSha) {
        throw "LibreOffice MSI SHA-256 mismatch: expected $expectedSha, got $actualSha."
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $msiPath
    Write-Host "MSI signature status: $($signature.Status)"
    if ($signature.SignerCertificate) {
        Write-Host "MSI signer: $($signature.SignerCertificate.Subject)"
    }
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "LibreOffice MSI Authenticode signature is not valid: $($signature.Status)"
    }

    # Build a Windows Installer administrative image instead of installing
    # LibreOffice into the CI host. VC_REDIST=0 prevents the MSI from servicing
    # the host Visual C++ runtime while we are only extracting vendor files.
    $msiexec = Join-Path $env:SystemRoot 'System32\msiexec.exe'
    $arguments = @(
        '/a',
        "`"$msiPath`"",
        '/qn',
        '/norestart',
        "TARGETDIR=`"$adminRoot`"",
        'VC_REDIST=0'
    )
    $process = Start-Process -FilePath $msiexec -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "LibreOffice administrative extraction failed with MSI exit code $($process.ExitCode)."
    }

    $sofficeCandidates = @(Get-ChildItem -LiteralPath $adminRoot -Recurse -Force -File -Filter 'soffice.exe' -ErrorAction Stop |
        Where-Object { $_.Directory -and $_.Directory.Name -ieq 'program' })
    if ($sofficeCandidates.Count -ne 1) {
        $sofficeCandidates | Select-Object FullName | Format-Table -AutoSize
        throw "Expected exactly one LibreOffice program/soffice.exe in administrative image; found $($sofficeCandidates.Count)."
    }

    $programRoot = $sofficeCandidates[0].Directory.FullName
    $officeRoot = Split-Path -Path $programRoot -Parent
    if (-not (Test-Path -LiteralPath (Join-Path $officeRoot 'share') -PathType Container)) {
        throw "Located soffice.exe but LibreOffice share/ directory is missing beside program/: $officeRoot"
    }

    # An MSI administrative image intentionally contains a transformed copy of
    # the source MSI next to the expanded application tree. That MSI is install
    # metadata, not a LibreOffice runtime dependency, so exclude it from the
    # xcopy-portable tree rather than shipping a redundant installer.
    Get-ChildItem -LiteralPath $officeRoot -Force | ForEach-Object {
        if (-not $_.PSIsContainer -and $_.Extension -ieq '.msi') {
            Write-Host "Excluding administrative-image MSI from portable runtime: $($_.Name)"
        }
        else {
            Copy-Item -LiteralPath $_.FullName -Destination $toolRoot -Recurse -Force
        }
    }

    $canonical = Join-Path $toolRoot 'program\soffice.exe'
    $sofficeBin = Join-Path $toolRoot 'program\soffice.bin'
    $versionIni = Join-Path $toolRoot 'program\version.ini'
    foreach ($required in @($canonical, $sofficeBin, $versionIni)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Extracted LibreOffice package is missing: $required"
        }
    }

    & rustc --edition 2021 -C opt-level=s -C strip=symbols -o $shim $launcher
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $shim -PathType Leaf)) {
        throw 'Failed to build the native relative LibreOffice launcher.'
    }

    $relativeHashes = [ordered]@{
        'program/soffice.exe' = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
        'program/soffice.bin' = (Get-FileHash -LiteralPath $sofficeBin -Algorithm SHA256).Hash.ToLowerInvariant()
        'program/version.ini' = (Get-FileHash -LiteralPath $versionIni -Algorithm SHA256).Hash.ToLowerInvariant()
        '../bin/soffice.exe' = (Get-FileHash -LiteralPath $shim -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    Set-Content -LiteralPath (Join-Path $toolRoot 'version.txt') -Encoding ascii -Value $Version
    Set-Content -LiteralPath (Join-Path $toolRoot 'PROVENANCE.txt') -Encoding utf8 -Value @(
        'NAME=LibreOffice',
        "VERSION=$Version",
        'ARCHITECTURE=x64',
        'PACKAGE_VARIANT=official-windows-x86-64-msi-administrative-image',
        "SOURCE_URL=$DownloadUrl",
        "MSI_SHA256=$actualSha",
        'EXTRACTION=Windows Installer administrative image (/a), VC_REDIST=0; administrative MSI excluded from runtime tree',
        'CANONICAL_EXE=program/soffice.exe',
        'STIRLING_PROBE=soffice',
        'STIRLING_SHIM=../bin/soffice.exe',
        'STIRLING_SHIM_MODE=native-relative-launcher',
        'TEMP_POLICY=data/tmp/libreoffice via launcher TEMP/TMP'
    )

    $shaLines = foreach ($entry in $relativeHashes.GetEnumerator()) {
        "$($entry.Value)  $($entry.Key)"
    }
    Set-Content -LiteralPath (Join-Path $toolRoot 'SHA256SUMS.txt') -Encoding ascii -Value $shaLines

    $leakedMsi = @(Get-ChildItem -LiteralPath $toolRoot -Recurse -Force -File -Filter '*.msi' -ErrorAction SilentlyContinue)
    if ($leakedMsi.Count -gt 0) {
        $leakedMsi | Select-Object FullName, Length | Format-Table -AutoSize
        throw 'LibreOffice source/admin MSI leaked into the portable tools tree.'
    }

    Write-Host "Staged LibreOffice $Version at $toolRoot with package-local soffice launcher $shim"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
