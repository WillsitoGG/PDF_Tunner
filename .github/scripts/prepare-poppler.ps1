[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][ValidateSet('windows-x64')][string]$PackageVariant,
    [Parameter(Mandatory = $true)][string]$DownloadUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSha256
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$popplerRoot = Join-Path $toolsRoot 'poppler'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-poppler-" + [Guid]::NewGuid().ToString('N'))
$archive = Join-Path $tempRoot ("poppler-{0}-{1}.zip" -f $Version, $PackageVariant)
$extractRoot = Join-Path $tempRoot 'extract'

try {
    Remove-Item -LiteralPath $popplerRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot, $tempRoot, $extractRoot | Out-Null

    Write-Host "Downloading Poppler $Version Windows x64 package from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $archive -UseBasicParsing

    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $ExpectedSha256.ToLowerInvariant()
    if ($archiveHash -ne $expectedHash) {
        throw "Poppler archive SHA-256 mismatch: expected $expectedHash, got $archiveHash."
    }

    Expand-Archive -LiteralPath $archive -DestinationPath $extractRoot -Force

    $pdftohtml = Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Filter 'pdftohtml.exe' |
        Where-Object { $_.Directory.Name -eq 'bin' -and $_.Directory.Parent.Name -eq 'Library' } |
        Select-Object -First 1
    if (-not $pdftohtml) {
        throw 'Poppler archive did not contain Library\bin\pdftohtml.exe.'
    }

    $libraryRoot = Split-Path -Parent $pdftohtml.Directory.FullName
    $sourceRoot = Split-Path -Parent $libraryRoot
    Copy-Item -LiteralPath $sourceRoot -Destination $popplerRoot -Recurse -Force

    $binRoot = Join-Path $popplerRoot 'Library\bin'
    $requiredExecutables = @('pdftohtml.exe', 'pdfinfo.exe', 'pdfimages.exe')
    $checksumLines = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $requiredExecutables) {
        $path = Join-Path $binRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Packaged Poppler executable is missing: $path"
        }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        $checksumLines.Add("$hash  Library/bin/$name")
    }

    Set-Content -LiteralPath (Join-Path $popplerRoot 'VERSION.txt') -Encoding ascii -Value $Version
    Set-Content -LiteralPath (Join-Path $popplerRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=Poppler',
        "VERSION=$Version",
        "PACKAGE_VARIANT=$PackageVariant",
        'UPSTREAM_PROJECT=https://poppler.freedesktop.org/',
        'WINDOWS_DISTRIBUTOR=https://github.com/oschwartz10612/poppler-windows',
        "SOURCE_URL=$DownloadUrl",
        "ARCHIVE_SHA256=$archiveHash"
    )
    Set-Content -LiteralPath (Join-Path $popplerRoot 'SHA256SUMS.txt') -Encoding ascii -Value $checksumLines

    $leftoverArchives = @(Get-ChildItem -LiteralPath $popplerRoot -Recurse -Force -File -Filter '*.zip' -ErrorAction SilentlyContinue)
    if ($leftoverArchives.Count -gt 0) {
        $leftoverArchives | Select-Object FullName, Length | Format-Table -AutoSize
        throw 'Downloaded Poppler archive leaked into the portable tool directory.'
    }

    Write-Host "Staged Poppler $Version at $popplerRoot"
    Write-Host "Archive SHA-256: $archiveHash"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
