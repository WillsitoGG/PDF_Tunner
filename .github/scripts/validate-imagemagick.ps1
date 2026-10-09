[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedArchiveSha256,

    [string]$BackendLogRoot,

    [switch]$RequireBackendProbe
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$imageMagickRoot = Join-Path $portable 'tools\imagemagick'
$magickExe = Join-Path $imageMagickRoot 'magick.exe'
$versionFile = Join-Path $imageMagickRoot 'version.txt'
$provenanceFile = Join-Path $imageMagickRoot 'PROVENANCE.txt'
$sumFile = Join-Path $imageMagickRoot 'SHA256SUMS.txt'
$tempRoot = Join-Path $portable 'data\tmp\imagemagick'
$validationRoot = Join-Path $tempRoot 'validation'

foreach ($required in @($magickExe, $versionFile, $provenanceFile, $sumFile)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Packaged ImageMagick file is missing: $required"
    }
}

$recordedVersion = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($recordedVersion -ne $Version) {
    throw "ImageMagick version.txt mismatch: expected $Version, got $recordedVersion."
}

$provenance = Get-Content -LiteralPath $provenanceFile -Raw
if ($provenance -notmatch '(?m)^ARCHIVE_SHA256=([0-9a-fA-F]{64})\s*$') {
    throw 'ImageMagick provenance does not contain ARCHIVE_SHA256.'
}
$recordedArchiveHash = $Matches[1].ToLowerInvariant()
$expectedArchiveHash = $ExpectedArchiveSha256.ToLowerInvariant()
if ($recordedArchiveHash -ne $expectedArchiveHash) {
    throw "ImageMagick provenance archive SHA mismatch: expected $expectedArchiveHash, got $recordedArchiveHash."
}
if ($provenance -notmatch ('(?m)^VERSION=' + [Regex]::Escape($Version) + '\s*$')) {
    throw "ImageMagick provenance does not report version $Version."
}

$sumLine = (Get-Content -LiteralPath $sumFile -Raw).Trim()
if ($sumLine -notmatch '^([0-9a-fA-F]{64})\s+magick\.exe$') {
    throw 'ImageMagick SHA256SUMS.txt has an unexpected format.'
}
$expectedExeHash = $Matches[1].ToLowerInvariant()
$actualExeHash = (Get-FileHash -LiteralPath $magickExe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualExeHash -ne $expectedExeHash) {
    throw "Packaged magick.exe SHA-256 mismatch: expected $expectedExeHash, got $actualExeHash."
}

# Prove the packaged executable itself is PE32+ AMD64 rather than trusting the asset name.
$stream = [System.IO.File]::Open($magickExe, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
$reader = $null
try {
    $reader = [System.IO.BinaryReader]::new($stream)
    if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'Packaged magick.exe does not have an MZ header.' }
    $stream.Position = 0x3C
    $peOffset = $reader.ReadUInt32()
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) { throw 'Packaged magick.exe does not have a PE signature.' }
    $machine = $reader.ReadUInt16()
    if ($machine -ne 0x8664) {
        throw ("Packaged magick.exe is not AMD64/x64; PE machine is 0x{0:X4}." -f $machine)
    }
}
finally {
    if ($null -ne $reader) { $reader.Dispose() }
    else { $stream.Dispose() }
}

$directVersion = (& $magickExe -version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Packaged magick.exe -version failed with exit code ${LASTEXITCODE}: $directVersion"
}
if ($directVersion -notmatch [Regex]::Escape($Version)) {
    throw "Packaged magick.exe did not report version $Version. Output: $directVersion"
}
if ($directVersion -notmatch 'Q16') {
    throw "Packaged magick.exe did not report the expected Q16 build. Output: $directVersion"
}
Write-Host $directVersion

$oldPath = $env:PATH
$oldHome = $env:MAGICK_HOME
$oldConfigure = $env:MAGICK_CONFIGURE_PATH
$oldTemporary = $env:MAGICK_TEMPORARY_PATH

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Remove-Item -LiteralPath $validationRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $validationRoot | Out-Null

    $windowsRoot = $env:SystemRoot
    $system32 = Join-Path $windowsRoot 'System32'
    $env:PATH = @($imageMagickRoot, $system32, $windowsRoot) -join ';'
    $env:MAGICK_HOME = $imageMagickRoot
    $env:MAGICK_CONFIGURE_PATH = $imageMagickRoot
    $env:MAGICK_TEMPORARY_PATH = $tempRoot

    $resolved = @(& (Join-Path $system32 'where.exe') magick 2>$null)
    if ($LASTEXITCODE -ne 0 -or $resolved.Count -lt 1) {
        throw 'Isolated PATH could not resolve magick.'
    }
    $resolvedFirst = [System.IO.Path]::GetFullPath($resolved[0].Trim())
    $expectedFirst = [System.IO.Path]::GetFullPath($magickExe)
    if (-not $resolvedFirst.Equals($expectedFirst, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Isolated PATH resolved the wrong magick executable: $resolvedFirst"
    }
    Write-Host "Isolated PATH resolves magick to package-local executable: $resolvedFirst"

    $isolatedVersion = (& magick -version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Package-first magick -version failed with exit code ${LASTEXITCODE}: $isolatedVersion"
    }
    if ($isolatedVersion -notmatch [Regex]::Escape($Version)) {
        throw "Package-first magick did not report version $Version. Output: $isolatedVersion"
    }

    $sample = Join-Path $validationRoot 'sample.png'
    & magick -size '32x32' 'xc:white' $sample
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $sample -PathType Leaf)) {
        throw 'Package-local ImageMagick failed to create the functional validation PNG.'
    }
    $dimensions = (& magick identify -format '%wx%h' $sample 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Package-local ImageMagick identify failed with exit code ${LASTEXITCODE}: $dimensions"
    }
    if ($dimensions -ne '32x32') {
        throw "Package-local ImageMagick functional result mismatch: expected 32x32, got '$dimensions'."
    }
    Write-Host 'ImageMagick functional PNG create/identify proof passed: 32x32.'

    if ($RequireBackendProbe) {
        if ([string]::IsNullOrWhiteSpace($BackendLogRoot) -or -not (Test-Path -LiteralPath $BackendLogRoot -PathType Container)) {
            throw 'RequireBackendProbe needs an existing BackendLogRoot.'
        }
        $backendText = (
            Get-ChildItem -LiteralPath $BackendLogRoot -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue |
                ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }
        ) -join "`n"
        if ($backendText -match '(?i)Missing dependency:\s*magick\b') {
            throw 'Stirling backend logs report packaged ImageMagick as a missing dependency.'
        }
        Write-Host 'Stirling backend logs do not report Missing dependency: magick.'
    }

    $leftoverArchives = @(Get-ChildItem -LiteralPath $imageMagickRoot -Recurse -Force -File -Filter '*.7z' -ErrorAction SilentlyContinue)
    if ($leftoverArchives.Count -gt 0) {
        $leftoverArchives | Select-Object FullName, Length | Format-Table -AutoSize
        throw 'ImageMagick archive is present inside the packaged tool directory.'
    }
}
finally {
    $env:PATH = $oldPath
    $env:MAGICK_HOME = $oldHome
    $env:MAGICK_CONFIGURE_PATH = $oldConfigure
    $env:MAGICK_TEMPORARY_PATH = $oldTemporary
    Remove-Item -LiteralPath $validationRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PASS: packaged ImageMagick $Version is x64/Q16, package-first and functionally usable."
