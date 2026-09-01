[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$PythonVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$PythonSha256,
    [Parameter(Mandatory = $true)][string]$OcrMyPdfVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$OcrMyPdfWheelSha256,
    [Parameter(Mandatory = $true)][string]$NumPyVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$NumPyWheelSha256,
    [Parameter(Mandatory = $true)][string]$DependencyLockPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$DependencyLockSha256,
    [switch]$RequireRelocation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$openCvSourceLock = (Resolve-Path -LiteralPath '.github/config/opencv-py312-windows-x64.lock.txt').Path
$expectedOpenCvDependencyLockSha256 = 'ec341586a884015445d4e28debbdd00b57ac903a36405bc7e0b9020e12dfd6c6'
$expectedOpenCvPackageName = 'opencv-python-headless'
$expectedOpenCvVersion = '4.14.0.94'
$expectedOpenCvWheelSha256 = 'cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b'
$splitPhotosScript = (Resolve-Path -LiteralPath './app/core/src/main/resources/static/python/split_photos.py').Path

function ConvertTo-NormalizedPackageName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return (($Name.ToLowerInvariant() -replace '[-_.]+', '-').Trim('-'))
}

function Read-DependencyLock {
    param([Parameter(Mandatory = $true)][string]$Path)
    $entries = @()
    $seenNames = @{}
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([A-Za-z0-9_.-]+)==([^\s]+)\s+--hash=sha256:([0-9a-fA-F]{64})$') {
            throw "Invalid dependency lock line: $trimmed"
        }
        $name = ConvertTo-NormalizedPackageName -Name $Matches[1]
        if ($seenNames.ContainsKey($name)) { throw "Duplicate package in dependency lock: $name" }
        $seenNames[$name] = $true
        $entries += [pscustomobject]@{
            Name = $name
            Version = $Matches[2]
            Hash = $Matches[3].ToLowerInvariant()
        }
    }
    if ($entries.Count -eq 0) { throw 'Dependency lock does not contain any packages.' }
    return $entries
}

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw "Not a valid PE/MZ executable: $Path" }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length) { throw "Invalid PE header offset in $Path" }
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) { throw "Missing PE signature in $Path" }
    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

function Get-KeyValueMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)
    $result = @{}
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        if ($line -match '^([^=]+)=(.*)$') { $result[$Matches[1]] = $Matches[2] }
    }
    return $result
}

function New-OcrFixture {
    param([Parameter(Mandatory = $true)][string]$Path)
    Add-Type -AssemblyName System.Drawing
    # OCRmyPDF rejects image inputs with an alpha channel. Construct the
    # synthetic scan explicitly as 24-bit RGB so the fixture represents a
    # conventional opaque scanned page rather than a 32-bit ARGB bitmap.
    $bitmap = [System.Drawing.Bitmap]::new(1800, 1000, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $font = New-Object System.Drawing.Font('Arial', 58, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.DrawString('PDF TUNNER OCRMY PDF 2026', $font, [System.Drawing.Brushes]::Black, 60, 120)
        $graphics.DrawString('SEARCHABLE TEXT LAYER', $font, [System.Drawing.Brushes]::Black, 60, 230)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $font.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    }
}

function Test-OcrRuntime {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][array]$ExpectedPackages,
        [Parameter(Mandatory = $true)][string]$ExpectedNumPyVersion,
        [Parameter(Mandatory = $true)][string]$ExpectedOpenCvVersion,
        [Parameter(Mandatory = $true)][string]$SplitPhotosScript
    )

    $pythonRoot = Join-Path $Root 'tools\python'
    $python = Join-Path $pythonRoot 'python.exe'
    $ocr = Join-Path $pythonRoot 'ocrmypdf.exe'
    $ghostscriptRoot = Join-Path $Root 'tools\ghostscript\bin'
    $tesseractRoot = Join-Path $Root 'tools\tesseract'
    $tessdata = Join-Path $tesseractRoot 'tessdata'

    foreach ($path in @($python, $ocr, (Join-Path $ghostscriptRoot 'gs.exe'), (Join-Path $tesseractRoot 'tesseract.exe'))) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required OCRmyPDF runtime file is missing: $path" }
    }
    if ((Get-PeMachine -Path $python) -ne 0x8664) { throw 'Bundled python.exe is not AMD64.' }
    if ((Get-PeMachine -Path $ocr) -ne 0x8664) { throw 'Bundled ocrmypdf.exe launcher is not AMD64.' }

    $oldPath = $env:PATH
    $oldTessdata = $env:TESSDATA_PREFIX
    try {
        $system32 = Join-Path $env:SystemRoot 'System32'
        $env:PATH = "$pythonRoot;$ghostscriptRoot;$tesseractRoot;$system32;$env:SystemRoot"
        $env:TESSDATA_PREFIX = $tessdata

        $expectations = @{
            'python' = $python
            'ocrmypdf' = $ocr
            'gs' = (Join-Path $ghostscriptRoot 'gs.exe')
            'tesseract' = (Join-Path $tesseractRoot 'tesseract.exe')
        }
        foreach ($name in $expectations.Keys) {
            $where = @(& where.exe $name 2>&1)
            if ($LASTEXITCODE -ne 0 -or $where.Count -eq 0) { throw "where.exe $name failed in isolated PATH." }
            $resolved = [System.IO.Path]::GetFullPath(($where[0] | Out-String).Trim())
            $expected = [System.IO.Path]::GetFullPath($expectations[$name])
            if ($resolved -ne $expected) { throw "Isolated PATH resolved $name outside package: $resolved (expected $expected)." }
        }

        $pyVersion = (@(& python --version 2>&1) -join ' ').Trim()
        if ($LASTEXITCODE -ne 0 -or $pyVersion -ne "Python $PythonVersion") { throw "Python version validation failed: '$pyVersion'." }
        $ocrVersion = (@(& ocrmypdf --version 2>&1) -join ' ').Trim()
        if ($LASTEXITCODE -ne 0 -or $ocrVersion -ne $OcrMyPdfVersion) { throw "OCRmyPDF version validation failed: '$ocrVersion'." }
        & python -m pip check | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "pip check failed with exit code $LASTEXITCODE." }
        $installedJson = (@(& python -m pip list --format=json --disable-pip-version-check) -join [Environment]::NewLine)
        if ($LASTEXITCODE -ne 0) { throw "pip list --format=json failed with exit code $LASTEXITCODE." }
        $installedPackages = @{}
        foreach ($package in @($installedJson | ConvertFrom-Json)) {
            $installedPackages[(ConvertTo-NormalizedPackageName -Name $package.name)] = $package.version
        }
        foreach ($entry in $ExpectedPackages) {
            if (-not $installedPackages.ContainsKey($entry.Name) -or $installedPackages[$entry.Name] -ne $entry.Version) {
                throw "Installed package does not match dependency lock: $($entry.Name)==$($entry.Version)."
            }
        }
        $bootstrapPackages = @('pip', 'setuptools', 'wheel')
        $unexpected = @($installedPackages.Keys | Where-Object { $_ -notin $bootstrapPackages -and $_ -notin $ExpectedPackages.Name })
        if ($unexpected.Count -gt 0) { throw "Unexpected packages outside dependency lock: $($unexpected -join ', ')" }

        $numpyProbeOutput = @(& python -c "import json, pathlib, numpy as np; from numpy._core import _multiarray_umath as core; a=np.array([[1,2],[3,4]], dtype=np.int64); b=np.array([[5,6],[7,8]], dtype=np.int64); result=a @ b; assert result.tolist() == [[19,22],[43,50]]; print(json.dumps({'version':np.__version__,'package':str(pathlib.Path(np.__file__).resolve()),'core':str(pathlib.Path(core.__file__).resolve()),'result':result.tolist()}))" 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $numpyProbeOutput | Out-Host
            throw "NumPy functional probe failed with exit code $LASTEXITCODE."
        }
        try {
            $numpyProbe = (($numpyProbeOutput -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop)
        }
        catch {
            $numpyProbeOutput | Out-Host
            throw 'NumPy functional probe did not emit valid JSON.'
        }
        if ($numpyProbe.version -ne $ExpectedNumPyVersion) {
            throw "NumPy version mismatch: expected '$ExpectedNumPyVersion', got '$($numpyProbe.version)'."
        }
        $pythonRootPrefix = [System.IO.Path]::GetFullPath($pythonRoot).TrimEnd('\') + '\'
        $numpyPackagePath = [System.IO.Path]::GetFullPath([string]$numpyProbe.package)
        $numpyCorePath = [System.IO.Path]::GetFullPath([string]$numpyProbe.core)
        foreach ($numpyPath in @($numpyPackagePath, $numpyCorePath)) {
            if (-not $numpyPath.StartsWith($pythonRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "NumPy resolved outside package-local Python: $numpyPath"
            }
        }
        if (-not (Test-Path -LiteralPath $numpyCorePath -PathType Leaf)) { throw "NumPy compiled core is missing: $numpyCorePath" }
        if ((Get-PeMachine -Path $numpyCorePath) -ne 0x8664) { throw "NumPy compiled core is not AMD64: $numpyCorePath" }
        $numpyDllRoot = Join-Path $pythonRoot 'Lib\site-packages\numpy.libs'
        $numpyDlls = @(Get-ChildItem -LiteralPath $numpyDllRoot -File -Filter '*.dll' -ErrorAction Stop)
        if ($numpyDlls.Count -eq 0) { throw "NumPy did not package its required native DLLs under $numpyDllRoot." }
        foreach ($numpyDll in $numpyDlls) {
            if ((Get-PeMachine -Path $numpyDll.FullName) -ne 0x8664) { throw "NumPy native DLL is not AMD64: $($numpyDll.FullName)" }
        }
        Write-Host "PASS: NumPy $ExpectedNumPyVersion package-local AMD64 import and deterministic matrix multiplication succeeded."

        $openCvProbeOutput = @(& python -c "import json, pathlib, cv2; print(json.dumps({'version':cv2.__version__,'package':str(pathlib.Path(cv2.__file__).resolve())}))" 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $openCvProbeOutput | Out-Host
            throw "OpenCV import probe failed with exit code $LASTEXITCODE."
        }
        try {
            $openCvProbe = (($openCvProbeOutput -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop)
        }
        catch {
            $openCvProbeOutput | Out-Host
            throw 'OpenCV import probe did not emit valid JSON.'
        }
        if ($openCvProbe.version -ne $ExpectedOpenCvVersion) {
            throw "OpenCV version mismatch: expected '$ExpectedOpenCvVersion', got '$($openCvProbe.version)'."
        }
        $openCvPackagePath = [System.IO.Path]::GetFullPath([string]$openCvProbe.package)
        if (-not $openCvPackagePath.StartsWith($pythonRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "OpenCV resolved outside package-local Python: $openCvPackagePath"
        }
        $openCvPackageRoot = Split-Path -Parent $openCvPackagePath
        $openCvNativeFiles = @(Get-ChildItem -LiteralPath $openCvPackageRoot -Recurse -File -ErrorAction Stop |
            Where-Object { $_.Extension -in @('.pyd', '.dll') })
        $openCvPyds = @($openCvNativeFiles | Where-Object { $_.Extension -eq '.pyd' })
        if ($openCvPyds.Count -eq 0) { throw "OpenCV did not package a native .pyd under $openCvPackageRoot." }
        foreach ($nativeFile in $openCvNativeFiles) {
            if ((Get-PeMachine -Path $nativeFile.FullName) -ne 0x8664) {
                throw "OpenCV native binary is not AMD64: $($nativeFile.FullName)"
            }
        }

        $openCvFixture = Join-Path $Root 'opencv-split-fixture.png'
        $openCvOutputDir = Join-Path $Root 'opencv-split-output'
        Remove-Item -LiteralPath $openCvFixture, $openCvOutputDir -Recurse -Force -ErrorAction SilentlyContinue
        $fixtureProbe = @(& python -c "import cv2, numpy as np, sys; img=np.full((500,900,3),255,dtype=np.uint8); cv2.rectangle(img,(50,75),(350,425),(20,40,180),-1); cv2.rectangle(img,(550,75),(850,425),(40,180,40),-1); assert cv2.imwrite(sys.argv[1],img)" $openCvFixture 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $fixtureProbe | Out-Host
            throw "OpenCV synthetic fixture creation failed with exit code $LASTEXITCODE."
        }
        $splitProbe = @(& python $SplitPhotosScript $openCvFixture $openCvOutputDir --tolerance 20 --min_area 10000 --min_contour_area 500 --angle_threshold 90 --border_size 0 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $splitProbe | Out-Host
            throw "Stirling split_photos.py OpenCV E2E failed with exit code $LASTEXITCODE."
        }
        $splitValidation = @(& python -c "import cv2, glob, json, os, sys; files=sorted(glob.glob(os.path.join(sys.argv[1],'*.png'))); assert len(files)==2, files; shapes=[cv2.imread(f).shape[:2] for f in files]; assert all(h >= 300 and w >= 250 for h,w in shapes), shapes; print(json.dumps({'count':len(files),'shapes':shapes}))" $openCvOutputDir 2>&1)
        if ($LASTEXITCODE -ne 0) {
            $splitValidation | Out-Host
            throw "Stirling split_photos.py output validation failed with exit code $LASTEXITCODE."
        }
        Remove-Item -LiteralPath $openCvFixture, $openCvOutputDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "PASS: OpenCV $ExpectedOpenCvVersion package-local AMD64 import and Stirling split_photos.py E2E succeeded."

        $fixture = Join-Path $Root 'ocrmypdf-fixture.png'
        $outputPdf = Join-Path $Root 'ocrmypdf-output.pdf'
        Remove-Item -LiteralPath $fixture, $outputPdf -Force -ErrorAction SilentlyContinue
        New-OcrFixture -Path $fixture

        # System.Drawing-generated PNG fixtures can inherit the runner display DPI
        # (for example ~95 DPI). OCRmyPDF correctly rejects that as an implausible
        # scan resolution, so declare the synthetic fixture's intended scan DPI.
        & ocrmypdf --output-type pdf --language eng --jobs 1 --image-dpi 300 $fixture $outputPdf 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Real OCRmyPDF conversion failed with exit code $LASTEXITCODE." }
        if (-not (Test-Path -LiteralPath $outputPdf -PathType Leaf)) { throw 'OCRmyPDF did not produce output PDF.' }
        if ((Get-Item -LiteralPath $outputPdf).Length -lt 1000) { throw 'OCRmyPDF output PDF is unexpectedly small.' }

        # OCRmyPDF 17.10.0 already depends on pdfminer-six. Reuse that packaged
        # dependency to prove a searchable text layer instead of adding pypdf only
        # for CI validation.
        $extract = @(& python -c "import sys; from pdfminer.high_level import extract_text; print(extract_text(sys.argv[1]))" $outputPdf 2>&1)
        if ($LASTEXITCODE -ne 0) { $extract | Out-Host; throw 'pdfminer text extraction from OCRmyPDF output failed.' }
        $normalized = (($extract -join ' ') -replace '[^A-Za-z0-9]+',' ').Trim().ToUpperInvariant()
        if ($normalized -notlike '*PDF TUNNER OCRMY PDF 2026*') {
            throw "OCRmyPDF output did not contain the expected searchable text layer: '$normalized'"
        }

        $runtimeTemp = Join-Path $Root 'data\tmp\ocrmypdf'
        $runtimeCache = Join-Path $Root 'data\python-cache'
        if (-not (Test-Path -LiteralPath $runtimeTemp -PathType Container)) { throw "Package-local OCRmyPDF temp was not created: $runtimeTemp" }
        if (-not (Test-Path -LiteralPath $runtimeCache -PathType Container)) { throw "Package-local Python cache was not created: $runtimeCache" }

        Remove-Item -LiteralPath $fixture, $outputPdf -Force -ErrorAction SilentlyContinue
    }
    finally {
        $env:PATH = $oldPath
        if ($null -eq $oldTessdata) { Remove-Item Env:TESSDATA_PREFIX -ErrorAction SilentlyContinue } else { $env:TESSDATA_PREFIX = $oldTessdata }
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$pythonRoot = Join-Path $portable 'tools\python'
$provenance = Join-Path $pythonRoot 'PROVENANCE.txt'
$shaFile = Join-Path $pythonRoot 'SHA256SUMS.txt'
$pythonVersionFile = Join-Path $pythonRoot 'PYTHON_VERSION.txt'
$ocrVersionFile = Join-Path $pythonRoot 'OCRMY_PDF_VERSION.txt'
$dependencies = Join-Path $pythonRoot 'DEPENDENCIES.txt'
$packagedLock = Join-Path $pythonRoot 'DEPENDENCY_LOCK.txt'
$packagedOpenCvLock = Join-Path $pythonRoot 'OPENCV_DEPENDENCY_LOCK.txt'
$openCvVersionFile = Join-Path $pythonRoot 'OPENCV_VERSION.txt'
$sourceLock = (Resolve-Path -LiteralPath $DependencyLockPath).Path
$sourceLockHash = (Get-FileHash -LiteralPath $sourceLock -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sourceLockHash -ne $DependencyLockSha256.ToLowerInvariant()) {
    throw "Source dependency lock SHA-256 mismatch: expected $($DependencyLockSha256.ToLowerInvariant()), got $sourceLockHash."
}
$lockEntries = @(Read-DependencyLock -Path $sourceLock)

$openCvSourceLockHash = (Get-FileHash -LiteralPath $openCvSourceLock -Algorithm SHA256).Hash.ToLowerInvariant()
if ($openCvSourceLockHash -ne $expectedOpenCvDependencyLockSha256) {
    throw "Source OpenCV dependency lock SHA-256 mismatch: expected $expectedOpenCvDependencyLockSha256, got $openCvSourceLockHash."
}
$openCvLockEntries = @(Read-DependencyLock -Path $openCvSourceLock)
if ($openCvLockEntries.Count -ne 1) { throw 'OpenCV dependency lock must contain exactly one package.' }
$openCvLockEntry = $openCvLockEntries[0]
if ($openCvLockEntry.Name -ne $expectedOpenCvPackageName -or $openCvLockEntry.Version -ne $expectedOpenCvVersion -or $openCvLockEntry.Hash -ne $expectedOpenCvWheelSha256) {
    throw "OpenCV dependency lock must contain exactly $expectedOpenCvPackageName==$expectedOpenCvVersion with the pinned Windows x64 wheel hash."
}
$expectedRuntimeEntries = @($lockEntries + $openCvLockEntries)

foreach ($path in @($provenance, $shaFile, $pythonVersionFile, $ocrVersionFile, $openCvVersionFile, $dependencies, $packagedLock, $packagedOpenCvLock)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Python/OCRmyPDF metadata file is missing: $path" }
}
$packagedLockHash = (Get-FileHash -LiteralPath $packagedLock -Algorithm SHA256).Hash.ToLowerInvariant()
if ($packagedLockHash -ne $sourceLockHash) { throw 'Packaged dependency lock does not match the repository lock.' }
$packagedOpenCvLockHash = (Get-FileHash -LiteralPath $packagedOpenCvLock -Algorithm SHA256).Hash.ToLowerInvariant()
if ($packagedOpenCvLockHash -ne $openCvSourceLockHash) { throw 'Packaged OpenCV dependency lock does not match the repository lock.' }
if ((Get-Content -LiteralPath $pythonVersionFile -Raw).Trim() -ne $PythonVersion) { throw 'PYTHON_VERSION.txt mismatch.' }
if ((Get-Content -LiteralPath $ocrVersionFile -Raw).Trim() -ne $OcrMyPdfVersion) { throw 'OCRMY_PDF_VERSION.txt mismatch.' }
if ((Get-Content -LiteralPath $openCvVersionFile -Raw).Trim() -ne $expectedOpenCvVersion) { throw 'OPENCV_VERSION.txt mismatch.' }

$metadata = Get-KeyValueMetadata -Path $provenance
$required = @{
    'PYTHON_VERSION' = $PythonVersion
    'PYTHON_ARCHIVE_SHA256' = $PythonSha256.ToLowerInvariant()
    'OCRMY_PDF_VERSION' = $OcrMyPdfVersion
    'OCRMY_PDF_WHEEL_SHA256' = $OcrMyPdfWheelSha256.ToLowerInvariant()
    'NUMPY_VERSION' = $NumPyVersion
    'NUMPY_WHEEL_SHA256' = $NumPyWheelSha256.ToLowerInvariant()
    'OPENCV_DISTRIBUTION' = $expectedOpenCvPackageName
    'OPENCV_VERSION' = $expectedOpenCvVersion
    'OPENCV_WHEEL_SHA256' = $expectedOpenCvWheelSha256
    'OPENCV_DEPENDENCY_LOCK_SHA256' = $expectedOpenCvDependencyLockSha256
    'PYTHON_DEPENDENCY_LOCK_SHA256' = $DependencyLockSha256.ToLowerInvariant()
    'PYTHON_DEPENDENCY_LOCK_PACKAGE_COUNT' = "$($lockEntries.Count)"
}
foreach ($key in $required.Keys) {
    if (-not $metadata.ContainsKey($key)) { throw "Python/OCRmyPDF provenance is missing $key." }
    if ($metadata[$key].ToLowerInvariant() -ne $required[$key].ToLowerInvariant()) {
        throw "Python/OCRmyPDF provenance mismatch for ${key}: expected '$($required[$key])', got '$($metadata[$key])'."
    }
}

$python = Join-Path $pythonRoot 'python.exe'
$ocr = Join-Path $pythonRoot 'ocrmypdf.exe'
$shaText = Get-Content -LiteralPath $shaFile -Raw
foreach ($item in @(@{Path=$python;Name='python.exe'}, @{Path=$ocr;Name='ocrmypdf.exe'}, @{Path=$packagedLock;Name='DEPENDENCY_LOCK.txt'}, @{Path=$packagedOpenCvLock;Name='OPENCV_DEPENDENCY_LOCK.txt'})) {
    $hash = (Get-FileHash -LiteralPath $item.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($shaText -notmatch "(?im)^$hash\s+$([Regex]::Escape($item.Name))\s*$") { throw "SHA256SUMS.txt does not contain $($item.Name)." }
}
if (@($lockEntries | Where-Object { $_.Name -eq 'ocrmypdf' -and $_.Version -eq $OcrMyPdfVersion -and $_.Hash -eq $OcrMyPdfWheelSha256.ToLowerInvariant() }).Count -ne 1) {
    throw 'Dependency lock does not contain the requested OCRmyPDF version and wheel hash.'
}
if (@($lockEntries | Where-Object { $_.Name -eq 'numpy' -and $_.Version -eq $NumPyVersion -and $_.Hash -eq $NumPyWheelSha256.ToLowerInvariant() }).Count -ne 1) {
    throw 'Dependency lock does not contain the requested NumPy version and wheel hash.'
}
if (@($openCvLockEntries | Where-Object { $_.Name -eq $expectedOpenCvPackageName -and $_.Version -eq $expectedOpenCvVersion -and $_.Hash -eq $expectedOpenCvWheelSha256 }).Count -ne 1) {
    throw 'OpenCV dependency lock does not contain the requested OpenCV distribution, version and wheel hash.'
}
$expectedInventory = @($expectedRuntimeEntries | Sort-Object Name | ForEach-Object { "$($_.Name)==$($_.Version)" })
$actualInventory = @(Get-Content -LiteralPath $dependencies | Where-Object { $_.Trim() })
$inventoryDiff = @(Compare-Object -ReferenceObject $expectedInventory -DifferenceObject $actualInventory)
if ($inventoryDiff.Count -gt 0) {
    $inventoryDiff | Format-Table -AutoSize | Out-Host
    throw 'DEPENDENCIES.txt does not exactly match the authenticated dependency lock.'
}

Test-OcrRuntime -Root $portable -ExpectedPackages $expectedRuntimeEntries -ExpectedNumPyVersion $NumPyVersion -ExpectedOpenCvVersion $expectedOpenCvVersion -SplitPhotosScript $splitPhotosScript

if ($RequireRelocation) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-ocr-relocation-" + [Guid]::NewGuid().ToString('N'))
    $relocated = Join-Path $tempRoot 'Relocated PDF_Tunner With Spaces'
    try {
        New-Item -ItemType Directory -Force -Path $relocated | Out-Null
        Copy-Item -LiteralPath (Join-Path $portable 'tools') -Destination $relocated -Recurse -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $relocated 'data') | Out-Null
        Test-OcrRuntime -Root $relocated -ExpectedPackages $expectedRuntimeEntries -ExpectedNumPyVersion $NumPyVersion -ExpectedOpenCvVersion $expectedOpenCvVersion -SplitPhotosScript $splitPhotosScript
        Write-Host "PASS: OCRmyPDF + NumPy + OpenCV runtime remains functional after relocation to '$relocated'."
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$backendLogRoot = Join-Path $portable 'data'
$backendLogs = @(Get-ChildItem -LiteralPath $backendLogRoot -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue)
if ($backendLogs.Count -gt 0) {
    $backendLogText = ($backendLogs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
    if ($backendLogText -match '(?im)Missing dependency:\s*Python with OpenCV\b') {
        throw 'Stirling backend reported Missing dependency: Python with OpenCV.'
    }
    if ($backendLogText -match '(?im)Disabling group:\s*OpenCV\b') {
        throw 'Stirling backend disabled the OpenCV dependency group.'
    }
    Write-Host 'PASS: Stirling backend did not disable the OpenCV dependency group.'
}

Write-Host "PASS: Python $PythonVersion + OCRmyPDF $OcrMyPdfVersion + NumPy $NumPyVersion + OpenCV $expectedOpenCvVersion functional validation succeeded."
