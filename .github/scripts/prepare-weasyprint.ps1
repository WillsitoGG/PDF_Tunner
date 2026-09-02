[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$DownloadUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$weasyRoot = Join-Path $toolsRoot 'weasyprint'
$binRoot = Join-Path $toolsRoot 'bin'
$temporaryParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$temporaryRoot = Join-Path $temporaryParent ("pdf-tunner-weasyprint-" + [Guid]::NewGuid().ToString('N'))
$archive = Join-Path $temporaryRoot "weasyprint-$Version-windows.zip"
$extractRoot = Join-Path $temporaryRoot 'extract'

try {
    Remove-Item -LiteralPath $weasyRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot, $binRoot, $weasyRoot, $temporaryRoot, $extractRoot | Out-Null

    Write-Host "Downloading official WeasyPrint $Version Windows release asset from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $archive -UseBasicParsing
    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $ExpectedSha256.ToLowerInvariant()
    if ($archiveHash -ne $expectedHash) {
        throw "WeasyPrint archive SHA-256 mismatch: expected $expectedHash, got $archiveHash."
    }

    Expand-Archive -LiteralPath $archive -DestinationPath $extractRoot -Force
    $officialExe = Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -File -Filter 'weasyprint.exe' | Select-Object -First 1
    if (-not $officialExe) {
        throw 'Official WeasyPrint Windows archive did not contain weasyprint.exe.'
    }

    $backend = Join-Path $weasyRoot 'weasyprint.exe'
    Copy-Item -LiteralPath $officialExe.FullName -Destination $backend -Force
    foreach ($name in @('LICENSE', 'README.rst')) {
        $file = Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -File -Filter $name | Select-Object -First 1
        if ($file) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $weasyRoot $name) -Force }
    }

    $launcherSourcePath = (Resolve-Path -LiteralPath $LauncherSource).Path
    $launcher = Join-Path $binRoot 'weasyprint.exe'
    Remove-Item -LiteralPath $launcher -Force -ErrorAction SilentlyContinue
    & rustc.exe --edition 2021 -O -C strip=symbols $launcherSourcePath -o $launcher
    if ($LASTEXITCODE -ne 0) { throw "rustc failed to build the package-local WeasyPrint launcher with exit code $LASTEXITCODE." }
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw "Rust completed without producing $launcher." }

    $backendHash = (Get-FileHash -LiteralPath $backend -Algorithm SHA256).Hash.ToLowerInvariant()
    $launcherHash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant()

    Set-Content -LiteralPath (Join-Path $weasyRoot 'VERSION.txt') -Encoding ascii -Value $Version
    Set-Content -LiteralPath (Join-Path $weasyRoot 'PROVENANCE.txt') -Encoding utf8 -Value @(
        'NAME=WeasyPrint',
        "VERSION=$Version",
        'UPSTREAM_PROJECT=https://github.com/Kozea/WeasyPrint',
        'DISTRIBUTION=Official Kozea Windows release asset built with PyInstaller one-file mode',
        "SOURCE_URL=$DownloadUrl",
        "ARCHIVE_SHA256=$archiveHash",
        'BACKEND=tools/weasyprint/weasyprint.exe',
        'PORTABLE_SHIM=tools/bin/weasyprint.exe',
        'TEMP_POLICY=data/tmp/weasyprint/run-<pid>-<timestamp> per invocation; removed on exit'
    )
    Set-Content -LiteralPath (Join-Path $weasyRoot 'SHA256SUMS.txt') -Encoding ascii -Value @(
        "$backendHash  weasyprint.exe",
        "$launcherHash  ../bin/weasyprint.exe"
    )
    Set-Content -LiteralPath (Join-Path $binRoot 'WEASYPRINT_PROVENANCE.txt') -Encoding utf8 -Value @(
        'NAME=PDF_Tunner WeasyPrint portable shim',
        'SOURCE=.github/scripts/weasyprint-launcher.rs',
        'BACKEND=tools/weasyprint/weasyprint.exe',
        "WEASYPRINT_VERSION=$Version",
        "SHA256=$launcherHash"
    )

    if (@(Get-ChildItem -LiteralPath $weasyRoot -Recurse -Force -File -Filter '*.zip' -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Downloaded WeasyPrint archive leaked into the portable package.'
    }

    Write-Host "Staged official WeasyPrint $Version at $weasyRoot"
    Write-Host "WeasyPrint archive SHA-256: $archiveHash"
    Write-Host "Official weasyprint.exe SHA-256: $backendHash"
    Write-Host "Portable shim SHA-256: $launcherHash"
}
finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}
