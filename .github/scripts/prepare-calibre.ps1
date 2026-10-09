[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$CalibreVersion,
    [Parameter(Mandatory = $true)][string]$CalibreMsiUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$CalibreMsiSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = [System.IO.Path]::GetFullPath($PortableRoot)
if (-not (Test-Path -LiteralPath $portable -PathType Container)) { throw "Portable root does not exist: $portable" }
$toolsRoot = Join-Path $portable 'tools'
$calibreRoot = Join-Path $toolsRoot 'calibre'
$binRoot = Join-Path $toolsRoot 'bin'
$temporaryParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$temporaryRoot = Join-Path $temporaryParent ("pdf-tunner-calibre-" + [Guid]::NewGuid().ToString('N'))
$msiPath = Join-Path $temporaryRoot "calibre-64bit-$CalibreVersion.msi"
$administrativeRoot = Join-Path $temporaryRoot 'administrative-extract'

try {
    New-Item -ItemType Directory -Force -Path $toolsRoot, $binRoot, $temporaryRoot, $administrativeRoot | Out-Null

    Write-Host "Downloading pinned Calibre $CalibreVersion Windows x64 MSI."
    Invoke-WebRequest -Uri $CalibreMsiUrl -OutFile $msiPath -UseBasicParsing
    $msiHash = (Get-FileHash -LiteralPath $msiPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($msiHash -ne $CalibreMsiSha256.ToLowerInvariant()) {
        throw "Calibre MSI SHA-256 mismatch: expected $($CalibreMsiSha256.ToLowerInvariant()), got $msiHash."
    }

    Write-Host 'Performing MSI administrative extraction only; Calibre is not installed on the runner.'
    $msiArgs = @('/a', ('"' + $msiPath + '"'), '/qn', ('TARGETDIR="' + $administrativeRoot + '"'))
    $msi = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') -ArgumentList $msiArgs -Wait -PassThru
    if ($msi.ExitCode -notin @(0, 3010)) {
        throw "Calibre administrative extraction failed with msiexec exit code $($msi.ExitCode)."
    }

    $ebookConvert = Get-ChildItem -LiteralPath $administrativeRoot -Recurse -Force -File -Filter 'ebook-convert.exe' | Select-Object -First 1
    if (-not $ebookConvert) { throw 'Administrative extraction completed but ebook-convert.exe was not found.' }
    $installRoot = $ebookConvert.Directory.FullName

    Remove-Item -LiteralPath $calibreRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $calibreRoot | Out-Null
    Get-ChildItem -LiteralPath $installRoot -Force | Copy-Item -Destination $calibreRoot -Recurse -Force

    $backend = Join-Path $calibreRoot 'ebook-convert.exe'
    if (-not (Test-Path -LiteralPath $backend -PathType Leaf)) { throw "Packaged Calibre backend is missing: $backend" }

    $launcherSourcePath = (Resolve-Path -LiteralPath $LauncherSource).Path
    $launcher = Join-Path $binRoot 'ebook-convert.exe'
    Remove-Item -LiteralPath $launcher -Force -ErrorAction SilentlyContinue
    & rustc.exe --edition 2021 -O -C strip=symbols $launcherSourcePath -o $launcher
    if ($LASTEXITCODE -ne 0) { throw "rustc failed to build the package-local Calibre launcher with exit code $LASTEXITCODE." }
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw "Rust completed without producing $launcher." }

    $backendHash = (Get-FileHash -LiteralPath $backend -Algorithm SHA256).Hash.ToLowerInvariant()
    $launcherHash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $calibreRoot 'VERSION.txt') -Encoding ascii -Value $CalibreVersion
    Set-Content -LiteralPath (Join-Path $calibreRoot 'PROVENANCE.txt') -Encoding utf8 -Value @(
        'NAME=PDF_Tunner Calibre portable runtime',
        "CALIBRE_VERSION=$CalibreVersion",
        'CALIBRE_ARCH=x86-64',
        "CALIBRE_MSI_URL=$CalibreMsiUrl",
        "CALIBRE_MSI_SHA256=$msiHash",
        'EXTRACTION_MODE=MSI administrative extraction; Calibre is not installed on the runner',
        'COMMAND_STRATEGY=tools/bin/ebook-convert.exe package-relative native launcher -> tools/calibre/ebook-convert.exe',
        'STATE=CALIBRE_CONFIG_DIRECTORY=data/calibre/config; CALIBRE_CACHE_DIRECTORY=data/calibre/cache; CALIBRE_TEMP_DIR=data/tmp/calibre/run-*; CALIBRE_NO_DEFAULT_PROGRAMS=1',
        'PATH_ORDER=tools/bin before tools/calibre before host PATH'
    )
    Set-Content -LiteralPath (Join-Path $calibreRoot 'SHA256SUMS.txt') -Encoding ascii -Value @(
        "$backendHash  ebook-convert.exe",
        "$launcherHash  ../bin/ebook-convert.exe"
    )
    Set-Content -LiteralPath (Join-Path $binRoot 'CALIBRE_PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=PDF_Tunner Calibre compatibility launcher',
        'SOURCE=.github/scripts/calibre-launcher.rs',
        'BACKEND=tools/calibre/ebook-convert.exe',
        "CALIBRE_VERSION=$CalibreVersion",
        "SHA256=$launcherHash"
    )

    Write-Host "Staged Calibre $CalibreVersion under $calibreRoot"
    Write-Host "Calibre MSI SHA-256: $msiHash"
    Write-Host "ebook-convert launcher SHA-256: $launcherHash"
}
finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}
