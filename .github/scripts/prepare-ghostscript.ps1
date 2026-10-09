[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('official-win64-nsis')]
    [string]$PackageVariant,

    [Parameter(Mandatory = $true)]
    [string]$DownloadUrl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedSha256
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$ghostscriptRoot = Join-Path $toolsRoot 'ghostscript'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-ghostscript-" + [Guid]::NewGuid().ToString('N'))
$installer = Join-Path $tempRoot 'ghostscript-win64.exe'
$extractRoot = Join-Path $tempRoot 'extract'

try {
    Remove-Item -LiteralPath $ghostscriptRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null

    Write-Host "Downloading official Ghostscript $Version Win64 package from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $installer -UseBasicParsing

    $installerHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $ExpectedSha256.ToLowerInvariant()
    if ($installerHash -ne $expectedHash) {
        throw "Ghostscript installer SHA-256 mismatch: expected $expectedHash, got $installerHash."
    }

    # The official Windows asset is an NSIS self-extracting package. Extract it
    # as an archive instead of executing the installer so staging cannot create
    # Ghostscript registry/uninstall state on the CI host that the portable copy
    # might accidentally depend on.
    $sevenZip = Get-Command '7z.exe' -ErrorAction Stop
    & $sevenZip.Source x $installer ("-o{0}" -f $extractRoot) -y | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip failed to extract the official Ghostscript NSIS package with exit code $LASTEXITCODE."
    }

    $consoleExe = Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -File -Filter 'gswin64c.exe' |
        Where-Object { $_.Directory.Name -ieq 'bin' } |
        Select-Object -First 1
    if (-not $consoleExe) {
        Write-Host 'Extracted Ghostscript tree:'
        Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue |
            Select-Object -First 250 FullName, Length | Format-Table -AutoSize
        throw 'Official Ghostscript package did not expose bin\gswin64c.exe after archive extraction.'
    }

    $sourceRoot = Split-Path -Parent $consoleExe.Directory.FullName
    $sourceLib = Join-Path $sourceRoot 'lib'
    if (-not (Test-Path -LiteralPath $sourceLib -PathType Container)) {
        Write-Host "Candidate Ghostscript source root: $sourceRoot"
        Get-ChildItem -LiteralPath $sourceRoot -Force -ErrorAction SilentlyContinue |
            Select-Object FullName, Length, Mode | Format-Table -AutoSize
        throw 'Extracted Ghostscript runtime root does not contain the expected lib directory.'
    }

    Copy-Item -LiteralPath $sourceRoot -Destination $ghostscriptRoot -Recurse -Force

    $packagedCanonical = Join-Path $ghostscriptRoot 'bin\gswin64c.exe'
    if (-not (Test-Path -LiteralPath $packagedCanonical -PathType Leaf)) {
        throw "Packaged Ghostscript console executable is missing: $packagedCanonical"
    }

    # Stirling 2.14.3 probes the literal command `gs`, while the official
    # Windows x64 console executable is named gswin64c.exe. Keep the canonical
    # executable and add a byte-identical package-local alias named gs.exe.
    $stirlingAlias = Join-Path $ghostscriptRoot 'bin\gs.exe'
    Copy-Item -LiteralPath $packagedCanonical -Destination $stirlingAlias -Force

    $reportedVersion = (& $packagedCanonical --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged gswin64c.exe --version failed with exit code $LASTEXITCODE."
    }
    if ($reportedVersion -ne $Version) {
        throw "Packaged Ghostscript version mismatch: expected $Version, got '$reportedVersion'."
    }

    $canonicalHash = (Get-FileHash -LiteralPath $packagedCanonical -Algorithm SHA256).Hash.ToLowerInvariant()
    $aliasHash = (Get-FileHash -LiteralPath $stirlingAlias -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($canonicalHash -ne $aliasHash) {
        throw 'Ghostscript Stirling alias is not byte-identical to the official gswin64c.exe.'
    }

    Set-Content -LiteralPath (Join-Path $ghostscriptRoot 'version.txt') -Encoding ascii -Value $Version
    Set-Content -LiteralPath (Join-Path $ghostscriptRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=Ghostscript',
        "VERSION=$Version",
        "PACKAGE_VARIANT=$PackageVariant",
        "SOURCE_URL=$DownloadUrl",
        "INSTALLER_SHA256=$installerHash",
        'CANONICAL_EXE=bin/gswin64c.exe',
        'STIRLING_ALIAS=bin/gs.exe',
        'STIRLING_ALIAS_MODE=byte-identical-copy'
    )
    Set-Content -LiteralPath (Join-Path $ghostscriptRoot 'SHA256SUMS.txt') -Encoding ascii -Value @(
        "$canonicalHash  bin/gswin64c.exe",
        "$aliasHash  bin/gs.exe"
    )

    $leakedInstallers = @(Get-ChildItem -LiteralPath $ghostscriptRoot -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq 'ghostscript-win64.exe' -or $_.Name -match '^gs\d+w64\.exe$' })
    if ($leakedInstallers.Count -gt 0) {
        $leakedInstallers | Select-Object FullName, Length | Format-Table -AutoSize
        throw 'Downloaded Ghostscript installer leaked into the portable tool directory.'
    }

    Write-Host "Staged Ghostscript $Version at $ghostscriptRoot"
    Write-Host "Installer SHA-256: $installerHash"
    Write-Host "Canonical/alias executable SHA-256: $canonicalHash"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
