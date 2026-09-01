[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$PythonVersion,
    [Parameter(Mandatory = $true)][string]$PythonDownloadUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$PythonSha256,
    [Parameter(Mandatory = $true)][string]$OcrMyPdfVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$OcrMyPdfWheelSha256,
    [Parameter(Mandatory = $true)][string]$NumPyVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$NumPyWheelSha256,
    [Parameter(Mandatory = $true)][string]$DependencyLockPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$DependencyLockSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function ConvertTo-NormalizedPackageName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return (($Name.ToLowerInvariant() -replace '[-_.]+', '-').Trim('-'))
}

function Read-DependencyLock {
    param([Parameter(Mandatory = $true)][string]$Path)
    $entries = @()
    $seenNames = @{}
    $seenHashes = @{}
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([A-Za-z0-9_.-]+)==([^\s]+)\s+--hash=sha256:([0-9a-fA-F]{64})$') {
            throw "Invalid dependency lock line: $trimmed"
        }
        $name = ConvertTo-NormalizedPackageName -Name $Matches[1]
        $version = $Matches[2]
        $hash = $Matches[3].ToLowerInvariant()
        if ($seenNames.ContainsKey($name)) { throw "Duplicate package in dependency lock: $name" }
        if ($seenHashes.ContainsKey($hash)) { throw "Duplicate wheel hash in dependency lock: $hash" }
        $seenNames[$name] = $true
        $seenHashes[$hash] = $true
        $entries += [pscustomobject]@{ Name = $name; Version = $version; Hash = $hash }
    }
    if ($entries.Count -eq 0) { throw 'Dependency lock does not contain any packages.' }
    return $entries
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$pythonRoot = Join-Path $toolsRoot 'python'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-ocrmypdf-" + [Guid]::NewGuid().ToString('N'))
$archive = Join-Path $tempRoot 'python-standalone.tar.gz'
$extractRoot = Join-Path $tempRoot 'extract'
$wheelRoot = Join-Path $tempRoot 'wheel'
$openCvWheelRoot = Join-Path $tempRoot 'opencv-wheel'
$dependencyLock = (Resolve-Path -LiteralPath $DependencyLockPath).Path
$openCvDependencyLock = (Resolve-Path -LiteralPath '.github/config/opencv-py312-windows-x64.lock.txt').Path
$expectedOpenCvDependencyLockSha256 = 'ec341586a884015445d4e28debbdd00b57ac903a36405bc7e0b9020e12dfd6c6'
$expectedOpenCvVersion = '4.14.0.94'
$expectedOpenCvWheelSha256 = 'cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b'
$dependencyLockHash = (Get-FileHash -LiteralPath $dependencyLock -Algorithm SHA256).Hash.ToLowerInvariant()
if ($dependencyLockHash -ne $DependencyLockSha256.ToLowerInvariant()) {
    throw "Python dependency lock SHA-256 mismatch: expected $($DependencyLockSha256.ToLowerInvariant()), got $dependencyLockHash."
}
$openCvDependencyLockHash = (Get-FileHash -LiteralPath $openCvDependencyLock -Algorithm SHA256).Hash.ToLowerInvariant()
if ($openCvDependencyLockHash -ne $expectedOpenCvDependencyLockSha256) {
    throw "OpenCV dependency lock SHA-256 mismatch: expected $expectedOpenCvDependencyLockSha256, got $openCvDependencyLockHash."
}
$lockEntries = @(Read-DependencyLock -Path $dependencyLock)
$openCvLockEntries = @(Read-DependencyLock -Path $openCvDependencyLock)
$ocrLockEntry = @($lockEntries | Where-Object { $_.Name -eq 'ocrmypdf' })
if ($ocrLockEntry.Count -ne 1 -or $ocrLockEntry[0].Version -ne $OcrMyPdfVersion) {
    throw "Dependency lock must contain exactly OCRmyPDF $OcrMyPdfVersion."
}
if ($ocrLockEntry[0].Hash -ne $OcrMyPdfWheelSha256.ToLowerInvariant()) {
    throw 'Dependency lock OCRmyPDF wheel hash does not match the workflow pin.'
}
$numpyLockEntry = @($lockEntries | Where-Object { $_.Name -eq 'numpy' })
if ($numpyLockEntry.Count -ne 1 -or $numpyLockEntry[0].Version -ne $NumPyVersion) {
    throw "Dependency lock must contain exactly NumPy $NumPyVersion."
}
if ($numpyLockEntry[0].Hash -ne $NumPyWheelSha256.ToLowerInvariant()) {
    throw 'Dependency lock NumPy wheel hash does not match the workflow pin.'
}
if ($openCvLockEntries.Count -ne 1 -or $openCvLockEntries[0].Name -ne 'opencv-python-headless' -or $openCvLockEntries[0].Version -ne $expectedOpenCvVersion) {
    throw "OpenCV dependency lock must contain exactly opencv-python-headless $expectedOpenCvVersion."
}
if ($openCvLockEntries[0].Hash -ne $expectedOpenCvWheelSha256) {
    throw 'OpenCV dependency lock wheel hash does not match the pinned Windows AMD64 wheel.'
}

try {
    Remove-Item -LiteralPath $pythonRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot, $tempRoot, $extractRoot, $wheelRoot, $openCvWheelRoot | Out-Null

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

    Write-Host "Downloading the $($lockEntries.Count)-package accepted Python wheelhouse from the authenticated base lock."
    & $python -m pip download --disable-pip-version-check --no-deps --only-binary=:all: --require-hashes --dest $wheelRoot --requirement $dependencyLock | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "pip download from dependency lock failed with exit code $LASTEXITCODE." }
    $wheels = @(Get-ChildItem -LiteralPath $wheelRoot -File -Filter '*.whl')
    if ($wheels.Count -ne $lockEntries.Count) {
        throw "Wheelhouse count mismatch: expected $($lockEntries.Count), got $($wheels.Count)."
    }
    $lockedHashes = @{}
    foreach ($entry in $lockEntries) { $lockedHashes[$entry.Hash] = $entry.Name }
    foreach ($lockedWheel in $wheels) {
        $downloadedHash = (Get-FileHash -LiteralPath $lockedWheel.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if (-not $lockedHashes.ContainsKey($downloadedHash)) {
            throw "Downloaded wheel is not authenticated by the lock: $($lockedWheel.Name) / $downloadedHash"
        }
    }
    $wheel = Get-ChildItem -LiteralPath $wheelRoot -File -Filter "ocrmypdf-$OcrMyPdfVersion-*.whl" | Select-Object -First 1
    if (-not $wheel) { throw 'Pinned OCRmyPDF wheel was not downloaded.' }
    $wheelHash = (Get-FileHash -LiteralPath $wheel.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($wheelHash -ne $OcrMyPdfWheelSha256.ToLowerInvariant()) {
        throw "OCRmyPDF wheel SHA-256 mismatch: expected $($OcrMyPdfWheelSha256.ToLowerInvariant()), got $wheelHash."
    }
    $numpyWheel = Get-ChildItem -LiteralPath $wheelRoot -File -Filter "numpy-$NumPyVersion-*.whl" | Select-Object -First 1
    if (-not $numpyWheel) { throw 'Pinned NumPy wheel was not downloaded.' }
    $numpyWheelHash = (Get-FileHash -LiteralPath $numpyWheel.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($numpyWheelHash -ne $NumPyWheelSha256.ToLowerInvariant()) {
        throw "NumPy wheel SHA-256 mismatch: expected $($NumPyWheelSha256.ToLowerInvariant()), got $numpyWheelHash."
    }

    & $python -m pip install --disable-pip-version-check --no-cache-dir --no-index --find-links $wheelRoot --only-binary=:all: --require-hashes --no-deps --requirement $dependencyLock | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Offline pip install from dependency lock failed with exit code $LASTEXITCODE." }

    Write-Host "Downloading authenticated OpenCV $expectedOpenCvVersion wheel separately so the accepted OCRmyPDF/NumPy base lock remains unchanged."
    & $python -m pip download --disable-pip-version-check --no-deps --only-binary=:all: --require-hashes --dest $openCvWheelRoot --requirement $openCvDependencyLock | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "pip download from OpenCV dependency lock failed with exit code $LASTEXITCODE." }
    $openCvWheels = @(Get-ChildItem -LiteralPath $openCvWheelRoot -File -Filter '*.whl')
    if ($openCvWheels.Count -ne 1) { throw "OpenCV wheelhouse count mismatch: expected 1, got $($openCvWheels.Count)." }
    $openCvWheel = $openCvWheels[0]
    if ($openCvWheel.Name -ne 'opencv_python_headless-4.14.0.94-cp37-abi3-win_amd64.whl') {
        throw "Unexpected OpenCV wheel selected for Windows x64: $($openCvWheel.Name)"
    }
    $openCvWheelHash = (Get-FileHash -LiteralPath $openCvWheel.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($openCvWheelHash -ne $expectedOpenCvWheelSha256) {
        throw "OpenCV wheel SHA-256 mismatch: expected $expectedOpenCvWheelSha256, got $openCvWheelHash."
    }
    & $python -m pip install --disable-pip-version-check --no-cache-dir --no-index --find-links $openCvWheelRoot --only-binary=:all: --require-hashes --no-deps --requirement $openCvDependencyLock | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Offline OpenCV install from dependency lock failed with exit code $LASTEXITCODE." }
    & $python -m pip check | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "pip check failed with exit code $LASTEXITCODE." }

    $installedJson = (@(& $python -m pip list --format=json --disable-pip-version-check) -join [Environment]::NewLine)
    if ($LASTEXITCODE -ne 0) { throw "pip list --format=json failed with exit code $LASTEXITCODE." }
    $installedPackages = @{}
    foreach ($package in @($installedJson | ConvertFrom-Json)) {
        $installedPackages[(ConvertTo-NormalizedPackageName -Name $package.name)] = $package.version
    }
    $expectedPackages = @($lockEntries + $openCvLockEntries)
    foreach ($entry in $expectedPackages) {
        if (-not $installedPackages.ContainsKey($entry.Name) -or $installedPackages[$entry.Name] -ne $entry.Version) {
            throw "Installed package does not match authenticated dependency locks: $($entry.Name)==$($entry.Version)."
        }
    }
    $bootstrapPackages = @('pip', 'setuptools', 'wheel')
    $unexpected = @($installedPackages.Keys | Where-Object { $_ -notin $bootstrapPackages -and $_ -notin $expectedPackages.Name })
    if ($unexpected.Count -gt 0) { throw "Unexpected packages outside dependency locks: $($unexpected -join ', ')" }

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

    $inventory = @($expectedPackages | Sort-Object Name | ForEach-Object { "$($_.Name)==$($_.Version)" })
    Set-Content -LiteralPath (Join-Path $pythonRoot 'DEPENDENCIES.txt') -Encoding utf8 -Value $inventory
    Copy-Item -LiteralPath $dependencyLock -Destination (Join-Path $pythonRoot 'DEPENDENCY_LOCK.txt') -Force
    Copy-Item -LiteralPath $openCvDependencyLock -Destination (Join-Path $pythonRoot 'OPENCV_DEPENDENCY_LOCK.txt') -Force
    Set-Content -LiteralPath (Join-Path $pythonRoot 'PYTHON_VERSION.txt') -Encoding ascii -Value $PythonVersion
    Set-Content -LiteralPath (Join-Path $pythonRoot 'OCRMY_PDF_VERSION.txt') -Encoding ascii -Value $OcrMyPdfVersion
    Set-Content -LiteralPath (Join-Path $pythonRoot 'OPENCV_VERSION.txt') -Encoding ascii -Value $expectedOpenCvVersion

    $pythonExeHash = (Get-FileHash -LiteralPath $python -Algorithm SHA256).Hash.ToLowerInvariant()
    $launcherHash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $pythonRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=PDF_Tunner Python + OCRmyPDF + NumPy + OpenCV runtime',
        "PYTHON_VERSION=$PythonVersion",
        'PYTHON_DISTRIBUTION=astral-sh/python-build-standalone install_only_stripped x86_64-pc-windows-msvc',
        "PYTHON_SOURCE_URL=$PythonDownloadUrl",
        "PYTHON_ARCHIVE_SHA256=$archiveHash",
        "OCRMY_PDF_VERSION=$OcrMyPdfVersion",
        "OCRMY_PDF_PYPI=https://pypi.org/project/ocrmypdf/$OcrMyPdfVersion/",
        "OCRMY_PDF_WHEEL_SHA256=$wheelHash",
        "NUMPY_VERSION=$NumPyVersion",
        "NUMPY_PYPI=https://pypi.org/project/numpy/$NumPyVersion/",
        "NUMPY_WHEEL_SHA256=$numpyWheelHash",
        "OPENCV_DISTRIBUTION=opencv-python-headless",
        "OPENCV_VERSION=$expectedOpenCvVersion",
        "OPENCV_PYPI=https://pypi.org/project/opencv-python-headless/$expectedOpenCvVersion/",
        "OPENCV_WHEEL_SHA256=$openCvWheelHash",
        "OPENCV_DEPENDENCY_LOCK_SHA256=$openCvDependencyLockHash",
        "PYTHON_DEPENDENCY_LOCK_SHA256=$dependencyLockHash",
        "PYTHON_DEPENDENCY_LOCK_PACKAGE_COUNT=$($lockEntries.Count)",
        'OCRMY_PDF_LAUNCHER=package-local native relative launcher -> python.exe -m ocrmypdf'
    )
    Set-Content -LiteralPath (Join-Path $pythonRoot 'SHA256SUMS.txt') -Encoding ascii -Value @(
        "$pythonExeHash  python.exe",
        "$launcherHash  ocrmypdf.exe",
        "$dependencyLockHash  DEPENDENCY_LOCK.txt",
        "$openCvDependencyLockHash  OPENCV_DEPENDENCY_LOCK.txt"
    )

    Write-Host "Staged Python $PythonVersion + OCRmyPDF $OcrMyPdfVersion + NumPy $NumPyVersion + OpenCV $expectedOpenCvVersion at $pythonRoot"
    Write-Host "Python archive SHA-256: $archiveHash"
    Write-Host "OCRmyPDF wheel SHA-256: $wheelHash"
    Write-Host "NumPy wheel SHA-256: $numpyWheelHash"
    Write-Host "OpenCV wheel SHA-256: $openCvWheelHash"
    Write-Host "OpenCV dependency lock SHA-256: $openCvDependencyLockHash"
    Write-Host "Python dependency lock SHA-256: $dependencyLockHash ($($lockEntries.Count) accepted base packages + 1 OpenCV package)"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
