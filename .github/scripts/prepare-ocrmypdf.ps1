[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$PythonVersion,
    [Parameter(Mandatory = $true)][string]$PythonDownloadUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$PythonSha256,
    [Parameter(Mandatory = $true)][string]$OcrMyPdfVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$OcrMyPdfWheelSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$pythonRoot = Join-Path $toolsRoot 'python'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-ocrmypdf-" + [Guid]::NewGuid().ToString('N'))
$archive = Join-Path $tempRoot 'python-standalone.tar.gz'
$extractRoot = Join-Path $tempRoot 'extract'
$wheelRoot = Join-Path $tempRoot 'wheel'

try {
    Remove-Item -LiteralPath $pythonRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot, $tempRoot, $extractRoot, $wheelRoot | Out-Null

    Write-Host "Downloading pinned Python standalone $PythonVersion from $PythonDownloadUrl"
    Invoke-WebRequest -Uri $PythonDownloadUrl -OutFile $archive -UseBasicParsing
    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($archiveHash -ne $PythonSha256.ToLowerInvariant()) {
        throw "Python standalone SHA-256 mismatch: expected $($PythonSha256.ToLowerInvariant()), got $archiveHash."
    }

    & tar.exe -xzf $archive -C $extractRoot
    if ($LASTEXITCODE -ne 0) { throw "tar.exe failed to extract Python standalone with exit code $LASTEXITCODE." }

    $candidate = Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -File -Filter 'python.exe' |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.Directory.FullName 'python3.dll') -PathType Leaf } |
        Select-Object -First 1
    if (-not $candidate) {
        Write-Host 'Extracted Python tree:'
        Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 300 FullName, Length | Format-Table -AutoSize
        throw 'Pinned Python standalone archive did not expose a usable python.exe runtime root.'
    }

    New-Item -ItemType Directory -Force -Path $pythonRoot | Out-Null
    Get-ChildItem -LiteralPath $candidate.Directory.FullName -Force | Copy-Item -Destination $pythonRoot -Recurse -Force
    $python = Join-Path $pythonRoot 'python.exe'

    $pythonVersionOutput = @(& $python --version 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Bundled Python --version failed with exit code $LASTEXITCODE." }
    $pythonVersionLine = ($pythonVersionOutput -join ' ').Trim()
    if ($pythonVersionLine -ne "Python $PythonVersion") {
        throw "Bundled Python version mismatch: expected 'Python $PythonVersion', got '$pythonVersionLine'."
    }

    & $python -m pip --version 2>$null | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'pip not present in standalone runtime; bootstrapping with ensurepip.'
        & $python -m ensurepip --upgrade | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "ensurepip failed with exit code $LASTEXITCODE." }
    }

    Write-Host "Downloading OCRmyPDF $OcrMyPdfVersion wheel for hash verification."
    & $python -m pip download --disable-pip-version-check --no-deps --only-binary=:all: --dest $wheelRoot "ocrmypdf==$OcrMyPdfVersion" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "pip download OCRmyPDF failed with exit code $LASTEXITCODE." }
    $wheel = Get-ChildItem -LiteralPath $wheelRoot -File -Filter "ocrmypdf-$OcrMyPdfVersion-*.whl" | Select-Object -First 1
    if (-not $wheel) { throw 'Pinned OCRmyPDF wheel was not downloaded.' }
    $wheelHash = (Get-FileHash -LiteralPath $wheel.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($wheelHash -ne $OcrMyPdfWheelSha256.ToLowerInvariant()) {
        throw "OCRmyPDF wheel SHA-256 mismatch: expected $($OcrMyPdfWheelSha256.ToLowerInvariant()), got $wheelHash."
    }

    & $python -m pip install --disable-pip-version-check --no-cache-dir $wheel.FullName | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "pip install OCRmyPDF failed with exit code $LASTEXITCODE." }
    & $python -m pip check | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "pip check failed with exit code $LASTEXITCODE." }

    $scriptsRoot = Join-Path $pythonRoot 'Scripts'
    Get-ChildItem -LiteralPath $scriptsRoot -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^ocrmypdf(?:-script\.py)?(?:\.exe)?$' } |
        Remove-Item -Force

    $launcher = Join-Path $pythonRoot 'ocrmypdf.exe'
    $launcherSourcePath = (Resolve-Path -LiteralPath $LauncherSource).Path
    & rustc.exe --edition 2021 -O -C strip=symbols $launcherSourcePath -o $launcher
    if ($LASTEXITCODE -ne 0) { throw "rustc failed to build relocatable OCRmyPDF launcher with exit code $LASTEXITCODE." }

    $ocrVersionOutput = @(& $launcher --version 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Packaged ocrmypdf --version failed with exit code $LASTEXITCODE." }
    $ocrVersionLine = ($ocrVersionOutput -join ' ').Trim()
    if ($ocrVersionLine -ne $OcrMyPdfVersion) {
        throw "OCRmyPDF version mismatch: expected '$OcrMyPdfVersion', got '$ocrVersionLine'."
    }

    # pip freeze preserves the direct local-wheel installation origin as a file://
    # reference, which is intentionally temporary and therefore unsuitable for a
    # reproducible package inventory. pip list --format=freeze reports the same
    # installed environment canonically as name==version, independent of origin.
    $inventory = @(& $python -m pip list --format=freeze --disable-pip-version-check)
    if ($LASTEXITCODE -ne 0) { throw "pip list --format=freeze failed with exit code $LASTEXITCODE." }
    Set-Content -LiteralPath (Join-Path $pythonRoot 'DEPENDENCIES.txt') -Encoding utf8 -Value ($inventory | Sort-Object)
    Set-Content -LiteralPath (Join-Path $pythonRoot 'PYTHON_VERSION.txt') -Encoding ascii -Value $PythonVersion
    Set-Content -LiteralPath (Join-Path $pythonRoot 'OCRMY_PDF_VERSION.txt') -Encoding ascii -Value $OcrMyPdfVersion

    $pythonExeHash = (Get-FileHash -LiteralPath $python -Algorithm SHA256).Hash.ToLowerInvariant()
    $launcherHash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $pythonRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=PDF_Tunner Python + OCRmyPDF runtime',
        "PYTHON_VERSION=$PythonVersion",
        'PYTHON_DISTRIBUTION=astral-sh/python-build-standalone install_only_stripped x86_64-pc-windows-msvc',
        "PYTHON_SOURCE_URL=$PythonDownloadUrl",
        "PYTHON_ARCHIVE_SHA256=$archiveHash",
        "OCRMY_PDF_VERSION=$OcrMyPdfVersion",
        "OCRMY_PDF_PYPI=https://pypi.org/project/ocrmypdf/$OcrMyPdfVersion/",
        "OCRMY_PDF_WHEEL_SHA256=$wheelHash",
        'OCRMY_PDF_LAUNCHER=package-local native relative launcher -> python.exe -m ocrmypdf'
    )
    Set-Content -LiteralPath (Join-Path $pythonRoot 'SHA256SUMS.txt') -Encoding ascii -Value @(
        "$pythonExeHash  python.exe",
        "$launcherHash  ocrmypdf.exe"
    )

    Write-Host "Staged Python $PythonVersion + OCRmyPDF $OcrMyPdfVersion at $pythonRoot"
    Write-Host "Python archive SHA-256: $archiveHash"
    Write-Host "OCRmyPDF wheel SHA-256: $wheelHash"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
