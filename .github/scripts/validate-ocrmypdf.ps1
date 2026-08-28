[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$PythonVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$PythonSha256,
    [Parameter(Mandatory = $true)][string]$OcrMyPdfVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$OcrMyPdfWheelSha256,
    [switch]$RequireRelocation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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
    $bitmap = New-Object System.Drawing.Bitmap 1800, 1000
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
    param([Parameter(Mandatory = $true)][string]$Root)

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

        $extract = @(& python -c "import sys; from pypdf import PdfReader; print(' '.join((p.extract_text() or '') for p in PdfReader(sys.argv[1]).pages))" $outputPdf 2>&1)
        if ($LASTEXITCODE -ne 0) { $extract | Out-Host; throw 'pypdf text extraction from OCRmyPDF output failed.' }
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

foreach ($path in @($provenance, $shaFile, $pythonVersionFile, $ocrVersionFile, $dependencies)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Python/OCRmyPDF metadata file is missing: $path" }
}
if ((Get-Content -LiteralPath $pythonVersionFile -Raw).Trim() -ne $PythonVersion) { throw 'PYTHON_VERSION.txt mismatch.' }
if ((Get-Content -LiteralPath $ocrVersionFile -Raw).Trim() -ne $OcrMyPdfVersion) { throw 'OCRMY_PDF_VERSION.txt mismatch.' }

$metadata = Get-KeyValueMetadata -Path $provenance
$required = @{
    'PYTHON_VERSION' = $PythonVersion
    'PYTHON_ARCHIVE_SHA256' = $PythonSha256.ToLowerInvariant()
    'OCRMY_PDF_VERSION' = $OcrMyPdfVersion
    'OCRMY_PDF_WHEEL_SHA256' = $OcrMyPdfWheelSha256.ToLowerInvariant()
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
foreach ($item in @(@{Path=$python;Name='python.exe'}, @{Path=$ocr;Name='ocrmypdf.exe'})) {
    $hash = (Get-FileHash -LiteralPath $item.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($shaText -notmatch "(?im)^$hash\s+$([Regex]::Escape($item.Name))\s*$") { throw "SHA256SUMS.txt does not contain $($item.Name)." }
}
if ((Get-Content -LiteralPath $dependencies -Raw) -notmatch "(?im)^ocrmypdf==$([Regex]::Escape($OcrMyPdfVersion))\s*$") {
    throw 'DEPENDENCIES.txt does not pin the requested OCRmyPDF version.'
}

Test-OcrRuntime -Root $portable

if ($RequireRelocation) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-ocr-relocation-" + [Guid]::NewGuid().ToString('N'))
    $relocated = Join-Path $tempRoot 'Relocated PDF_Tunner With Spaces'
    try {
        New-Item -ItemType Directory -Force -Path $relocated | Out-Null
        Copy-Item -LiteralPath (Join-Path $portable 'tools') -Destination $relocated -Recurse -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $relocated 'data') | Out-Null
        Test-OcrRuntime -Root $relocated
        Write-Host "PASS: OCRmyPDF runtime remains functional after relocation to '$relocated'."
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "PASS: Python $PythonVersion + OCRmyPDF $OcrMyPdfVersion real OCR/searchable-text validation succeeded."
