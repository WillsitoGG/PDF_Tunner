[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('msvc64')]
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
$qpdfRoot = Join-Path $toolsRoot 'qpdf'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-qpdf-" + [Guid]::NewGuid().ToString('N'))
$archive = Join-Path $tempRoot ("qpdf-{0}-{1}.zip" -f $Version, $PackageVariant)
$extractRoot = Join-Path $tempRoot 'extract'

try {
    Remove-Item -LiteralPath $qpdfRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null

    Write-Host "Downloading official qpdf $Version ($PackageVariant) from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $archive -UseBasicParsing

    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $ExpectedSha256.ToLowerInvariant()
    if ($archiveHash -ne $expectedHash) {
        throw "qpdf archive SHA-256 mismatch: expected $expectedHash, got $archiveHash."
    }

    Expand-Archive -LiteralPath $archive -DestinationPath $extractRoot -Force

    $qpdfExe = Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Filter 'qpdf.exe' |
        Where-Object { $_.Directory.Name -eq 'bin' } |
        Select-Object -First 1
    if (-not $qpdfExe) {
        throw 'Official qpdf archive did not contain bin\qpdf.exe.'
    }

    $sourceRoot = Split-Path -Parent (Split-Path -Parent $qpdfExe.FullName)
    Copy-Item -LiteralPath $sourceRoot -Destination $qpdfRoot -Recurse -Force

    $packagedExe = Join-Path $qpdfRoot 'bin\qpdf.exe'
    if (-not (Test-Path -LiteralPath $packagedExe -PathType Leaf)) {
        throw "Packaged qpdf executable is missing: $packagedExe"
    }

    $exeHash = (Get-FileHash -LiteralPath $packagedExe -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $qpdfRoot 'version.txt') -Encoding ascii -Value $Version
    Set-Content -LiteralPath (Join-Path $qpdfRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=qpdf',
        "VERSION=$Version",
        "PACKAGE_VARIANT=$PackageVariant",
        "SOURCE_URL=$DownloadUrl",
        "ARCHIVE_SHA256=$archiveHash"
    )
    Set-Content -LiteralPath (Join-Path $qpdfRoot 'SHA256SUMS.txt') -Encoding ascii -Value (
        "$exeHash  bin/qpdf.exe"
    )

    $leftoverArchives = @(Get-ChildItem -LiteralPath $qpdfRoot -Recurse -Force -File -Filter '*.zip' -ErrorAction SilentlyContinue)
    if ($leftoverArchives.Count -gt 0) {
        $leftoverArchives | Select-Object FullName, Length | Format-Table -AutoSize
        throw 'Downloaded qpdf archive leaked into the portable tool directory.'
    }

    Write-Host "Staged qpdf $Version at $qpdfRoot"
    Write-Host "Archive SHA-256: $archiveHash"
    Write-Host "Packaged qpdf.exe SHA-256: $exeHash"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
