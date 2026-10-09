[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('portable-Q16-x64')]
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
$imageMagickRoot = Join-Path $toolsRoot 'imagemagick'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-imagemagick-" + [Guid]::NewGuid().ToString('N'))
$archive = Join-Path $tempRoot ("ImageMagick-{0}-{1}.7z" -f $Version, $PackageVariant)
$extractRoot = Join-Path $tempRoot 'extract'

try {
    Remove-Item -LiteralPath $imageMagickRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null

    Write-Host "Downloading official ImageMagick $Version ($PackageVariant) from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $archive -UseBasicParsing

    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $ExpectedSha256.ToLowerInvariant()
    if ($archiveHash -ne $expectedHash) {
        throw "ImageMagick archive SHA-256 mismatch: expected $expectedHash, got $archiveHash."
    }

    $sevenZip = Get-Command '7z.exe' -ErrorAction Stop
    & $sevenZip.Source x $archive ("-o{0}" -f $extractRoot) -y | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip failed to extract the official ImageMagick archive with exit code $LASTEXITCODE."
    }

    $magickExe = Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Filter 'magick.exe' |
        Select-Object -First 1
    if (-not $magickExe) {
        throw 'Official ImageMagick archive did not contain magick.exe.'
    }

    $sourceRoot = $magickExe.Directory.FullName
    Copy-Item -LiteralPath $sourceRoot -Destination $imageMagickRoot -Recurse -Force

    $packagedExe = Join-Path $imageMagickRoot 'magick.exe'
    if (-not (Test-Path -LiteralPath $packagedExe -PathType Leaf)) {
        throw "Packaged ImageMagick executable is missing: $packagedExe"
    }

    $exeHash = (Get-FileHash -LiteralPath $packagedExe -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $imageMagickRoot 'version.txt') -Encoding ascii -Value $Version
    Set-Content -LiteralPath (Join-Path $imageMagickRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=ImageMagick',
        "VERSION=$Version",
        "PACKAGE_VARIANT=$PackageVariant",
        "SOURCE_URL=$DownloadUrl",
        "ARCHIVE_SHA256=$archiveHash"
    )
    Set-Content -LiteralPath (Join-Path $imageMagickRoot 'SHA256SUMS.txt') -Encoding ascii -Value (
        "$exeHash  magick.exe"
    )

    $leftoverArchives = @(Get-ChildItem -LiteralPath $imageMagickRoot -Recurse -Force -File -Filter '*.7z' -ErrorAction SilentlyContinue)
    if ($leftoverArchives.Count -gt 0) {
        $leftoverArchives | Select-Object FullName, Length | Format-Table -AutoSize
        throw 'Downloaded ImageMagick archive leaked into the portable tool directory.'
    }

    Write-Host "Staged ImageMagick $Version at $imageMagickRoot"
    Write-Host "Archive SHA-256: $archiveHash"
    Write-Host "Packaged magick.exe SHA-256: $exeHash"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
