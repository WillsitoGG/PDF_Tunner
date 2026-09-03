[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$unpaperVersion = '6.1'
$unpaperUrl = 'https://github.com/rodrigost23/unpaper/releases/download/unpaper-6.1/unpaper-6.1-windows-x86_64.zip'
$unpaperSha256 = 'a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65'
$pngquantVersion = '3.0.3'
$pngquantUrl = 'https://pngquant.org/pngquant-windows.zip'
$pngquantSha256 = 'bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d'
$unpaperRuntimeFiles = @('unpaper.exe', 'LIBBZ2-1.DLL', 'LIBWINPTHREAD-1.DLL', 'ZLIB1.DLL')

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw "Not a PE/MZ binary: $Path" }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length) { throw "Invalid PE header offset in $Path" }
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) { throw "Missing PE signature in $Path" }
    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

function Assert-Hash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "$Label SHA-256 mismatch: expected $($Expected.ToLowerInvariant()), got $actual."
    }
    return $actual
}

function New-OcrAuxFixture {
    param([Parameter(Mandatory = $true)][string]$Path)
    Add-Type -AssemblyName System.Drawing
    $bitmap = [System.Drawing.Bitmap]::new(1800, 1000, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $font = New-Object System.Drawing.Font('Arial', 58, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.DrawString('PDF TUNNER OCR AUX 2026', $font, [System.Drawing.Brushes]::Black, 70, 140)
        $graphics.DrawString('UNPAPER PNGQUANT', $font, [System.Drawing.Brushes]::Black, 70, 260)
        $graphics.FillRectangle([System.Drawing.Brushes]::LightBlue, 70, 430, 1550, 260)
        $graphics.FillEllipse([System.Drawing.Brushes]::DarkOrange, 250, 470, 420, 160)
        $graphics.FillRectangle([System.Drawing.Brushes]::DarkGreen, 850, 470, 500, 160)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $font.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    }
}

function Test-OcrAuxRuntime {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$PythonRoot,
        [switch]$RunFullOcr
    )

    $binRoot = Join-Path $Root 'tools\bin'
    $unpaper = Join-Path $binRoot 'unpaper.exe'
    $pngquant = Join-Path $binRoot 'pngquant.exe'
    $python = Join-Path $PythonRoot 'python.exe'
    $ocr = Join-Path $PythonRoot 'ocrmypdf.exe'
    foreach ($path in @($unpaper, $pngquant, $python, $ocr)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required OCR auxiliary runtime file is missing: $path" }
    }
    foreach ($name in $unpaperRuntimeFiles) {
        $path = Join-Path $binRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required unpaper runtime file is missing: $path" }
        if ((Get-PeMachine -Path $path) -ne 0x8664) { throw "Unpaper runtime is not AMD64: $path" }
    }
    if ((Get-PeMachine -Path $pngquant) -ne 0x8664) { throw "pngquant.exe is not AMD64: $pngquant" }

    $oldPath = $env:PATH
    $oldTessdata = $env:TESSDATA_PREFIX
    try {
        $system32 = Join-Path $env:SystemRoot 'System32'
        $pathParts = @($binRoot, $PythonRoot)
        if ($RunFullOcr) {
            $ghostscriptRoot = Join-Path $Root 'tools\ghostscript\bin'
            $tesseractRoot = Join-Path $Root 'tools\tesseract'
            $tessdata = Join-Path $tesseractRoot 'tessdata'
            foreach ($required in @((Join-Path $ghostscriptRoot 'gs.exe'), (Join-Path $tesseractRoot 'tesseract.exe'), (Join-Path $tessdata 'eng.traineddata'))) {
                if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required full OCR runtime file is missing: $required" }
            }
            $pathParts += @($ghostscriptRoot, $tesseractRoot)
            $env:TESSDATA_PREFIX = $tessdata
        }
        $pathParts += @($system32, $env:SystemRoot)
        $env:PATH = ($pathParts -join ';')

        foreach ($expectation in @(
            @{Name='unpaper'; Path=$unpaper},
            @{Name='pngquant'; Path=$pngquant}
        )) {
            $resolvedOutput = @(& where.exe $expectation.Name 2>&1)
            if ($LASTEXITCODE -ne 0 -or $resolvedOutput.Count -eq 0) { throw "where.exe $($expectation.Name) failed in isolated PATH." }
            $resolved = [System.IO.Path]::GetFullPath(($resolvedOutput[0] | Out-String).Trim())
            $expected = [System.IO.Path]::GetFullPath($expectation.Path)
            if ($resolved -ne $expected) { throw "Isolated PATH resolved $($expectation.Name) outside package: $resolved (expected $expected)." }
        }

        $unpaperVersionOutput = (@(& unpaper --version 2>&1) -join ' ').Trim()
        if ($LASTEXITCODE -ne 0 -or $unpaperVersionOutput -notmatch '(?<!\d)6\.1(?!\d)') {
            throw "unpaper version validation failed: '$unpaperVersionOutput'."
        }
        $pngquantVersionOutput = (@(& pngquant --version 2>&1) -join ' ').Trim()
        if ($LASTEXITCODE -ne 0 -or $pngquantVersionOutput -notmatch '(?<!\d)3\.0\.3(?!\d)') {
            throw "pngquant version validation failed: '$pngquantVersionOutput'."
        }

        $probe = @(& $python -c "from ocrmypdf._exec import unpaper, pngquant; assert unpaper.available(); assert pngquant.available(); print('unpaper=' + str(unpaper.version())); print('pngquant=' + str(pngquant.version()))" 2>&1)
        if ($LASTEXITCODE -ne 0) { $probe | Out-Host; throw 'OCRmyPDF did not detect packaged unpaper/pngquant.' }
        $probeText = ($probe -join ' ')
        if ($probeText -notmatch 'unpaper=6\.1' -or $probeText -notmatch 'pngquant=3\.0\.3') {
            throw "OCRmyPDF dependency probe returned unexpected versions: $probeText"
        }

        $fixture = Join-Path $Root 'ocr-aux-fixture.png'
        $unpaperOutput = Join-Path $Root 'ocr-aux-unpaper.pnm'
        $pngquantOutput = Join-Path $Root 'ocr-aux-pngquant.png'
        Remove-Item -LiteralPath $fixture, $unpaperOutput, $pngquantOutput -Force -ErrorAction SilentlyContinue
        New-OcrAuxFixture -Path $fixture

        $unpaperProbe = @(& $python -c "from pathlib import Path; import sys; from ocrmypdf._exec import unpaper; args=['--layout','none','--mask-scan-size','100','--no-border-align','--no-mask-center','--no-grayfilter','--no-blackfilter','--no-deskew']; unpaper.run_unpaper(Path(sys.argv[1]), Path(sys.argv[2]), dpi=300, mode_args=args); assert Path(sys.argv[2]).stat().st_size > 1000" $fixture $unpaperOutput 2>&1)
        if ($LASTEXITCODE -ne 0) { $unpaperProbe | Out-Host; throw 'OCRmyPDF unpaper wrapper functional test failed.' }

        $pngquantProbe = @(& $python -c "from pathlib import Path; import sys; from PIL import Image; from ocrmypdf._exec import pngquant; src=Path(sys.argv[1]); dst=Path(sys.argv[2]); pngquant.quantize(src,dst,50,90); assert dst.is_file() and dst.stat().st_size > 100; im=Image.open(dst); im.verify()" $fixture $pngquantOutput 2>&1)
        if ($LASTEXITCODE -ne 0) { $pngquantProbe | Out-Host; throw 'OCRmyPDF pngquant wrapper functional test failed.' }

        if ($RunFullOcr) {
            $cleanPdf = Join-Path $Root 'ocr-aux-clean-output.pdf'
            Remove-Item -LiteralPath $cleanPdf -Force -ErrorAction SilentlyContinue
            $ocrOutput = @(& $ocr --verbose 2 --output-type pdf --language eng --jobs 1 --image-dpi 300 --clean --clean-final $fixture $cleanPdf 2>&1)
            if ($LASTEXITCODE -ne 0) { $ocrOutput | Out-Host; throw "OCRmyPDF --clean/--clean-final integration failed with exit code $LASTEXITCODE." }
            if (-not (Test-Path -LiteralPath $cleanPdf -PathType Leaf) -or (Get-Item -LiteralPath $cleanPdf).Length -lt 1000) {
                throw 'OCRmyPDF --clean/--clean-final did not produce a valid-sized PDF.'
            }
            Remove-Item -LiteralPath $cleanPdf -Force -ErrorAction SilentlyContinue
        }

        Remove-Item -LiteralPath $fixture, $unpaperOutput, $pngquantOutput -Force -ErrorAction SilentlyContinue
        Write-Host "PASS: unpaper $unpaperVersion and pngquant $pngquantVersion are package-first, AMD64 and exercised through OCRmyPDF 17.10.0."
    }
    finally {
        $env:PATH = $oldPath
        if ($null -eq $oldTessdata) { Remove-Item Env:TESSDATA_PREFIX -ErrorAction SilentlyContinue } else { $env:TESSDATA_PREFIX = $oldTessdata }
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$binRoot = Join-Path $toolsRoot 'bin'
$pythonRoot = Join-Path $toolsRoot 'python'
if (-not (Test-Path -LiteralPath $pythonRoot -PathType Container)) { throw "Accepted Python/OCRmyPDF runtime is missing: $pythonRoot" }
New-Item -ItemType Directory -Force -Path $binRoot | Out-Null

$tempParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$tempRoot = Join-Path $tempParent ("pdf-tunner-ocr-aux-" + [Guid]::NewGuid().ToString('N'))
$unpaperArchive = Join-Path $tempRoot 'unpaper.zip'
$pngquantArchive = Join-Path $tempRoot 'pngquant.zip'
$unpaperExtract = Join-Path $tempRoot 'unpaper'
$pngquantExtract = Join-Path $tempRoot 'pngquant'

try {
    New-Item -ItemType Directory -Force -Path $tempRoot, $unpaperExtract, $pngquantExtract | Out-Null

    Write-Host "Downloading pinned unpaper $unpaperVersion Windows x86_64 community build."
    Invoke-WebRequest -Uri $unpaperUrl -OutFile $unpaperArchive -UseBasicParsing
    $actualUnpaperArchiveHash = Assert-Hash -Path $unpaperArchive -Expected $unpaperSha256 -Label 'unpaper archive'
    Expand-Archive -LiteralPath $unpaperArchive -DestinationPath $unpaperExtract -Force
    $unpaperExeSource = Get-ChildItem -LiteralPath $unpaperExtract -Recurse -Force -File -Filter 'unpaper.exe' | Select-Object -First 1
    if (-not $unpaperExeSource) { throw 'Pinned unpaper archive did not contain unpaper.exe.' }
    foreach ($name in $unpaperRuntimeFiles) {
        $source = Get-ChildItem -LiteralPath $unpaperExeSource.Directory.FullName -File | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
        if (-not $source) { throw "Pinned unpaper archive is missing required sibling runtime: $name" }
        Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $binRoot $name) -Force
    }

    Write-Host "Downloading pinned pngquant $pngquantVersion official Windows archive."
    Invoke-WebRequest -Uri $pngquantUrl -OutFile $pngquantArchive -UseBasicParsing
    $actualPngquantArchiveHash = Assert-Hash -Path $pngquantArchive -Expected $pngquantSha256 -Label 'pngquant archive'
    Expand-Archive -LiteralPath $pngquantArchive -DestinationPath $pngquantExtract -Force
    $pngquantExeSource = Get-ChildItem -LiteralPath $pngquantExtract -Recurse -Force -File -Filter 'pngquant.exe' | Select-Object -First 1
    if (-not $pngquantExeSource) { throw 'Pinned pngquant archive did not contain pngquant.exe.' }
    Copy-Item -LiteralPath $pngquantExeSource.FullName -Destination (Join-Path $binRoot 'pngquant.exe') -Force

    Test-OcrAuxRuntime -Root $portable -PythonRoot $pythonRoot -RunFullOcr

    $relocationRoot = Join-Path $tempRoot 'Relocated PDF_Tunner Aux With Spaces'
    $relocatedBin = Join-Path $relocationRoot 'tools\bin'
    New-Item -ItemType Directory -Force -Path $relocatedBin | Out-Null
    foreach ($name in @($unpaperRuntimeFiles + 'pngquant.exe')) {
        Copy-Item -LiteralPath (Join-Path $binRoot $name) -Destination (Join-Path $relocatedBin $name) -Force
    }
    Test-OcrAuxRuntime -Root $relocationRoot -PythonRoot $pythonRoot
    Write-Host "PASS: OCR auxiliary binaries remain functional after relocation to '$relocationRoot'."

    $provenance = Join-Path $pythonRoot 'PROVENANCE.txt'
    $shaFile = Join-Path $pythonRoot 'SHA256SUMS.txt'
    foreach ($required in @($provenance, $shaFile)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Accepted Python metadata file is missing: $required" }
    }

    $existingProvenance = @(Get-Content -LiteralPath $provenance | Where-Object { $_ -notmatch '^(UNPAPER|PNGQUANT)_' })
    $existingProvenance += @(
        "UNPAPER_VERSION=$unpaperVersion",
        'UNPAPER_DISTRIBUTION=rodrigost23/unpaper Windows x86_64 community build; upstream unpaper 7.0.0 publishes source only',
        "UNPAPER_SOURCE_URL=$unpaperUrl",
        "UNPAPER_ARCHIVE_SHA256=$actualUnpaperArchiveHash",
        'UNPAPER_ROLE=OCRmyPDF --clean and --clean-final',
        "PNGQUANT_VERSION=$pngquantVersion",
        'PNGQUANT_DISTRIBUTION=official pngquant.org Windows archive',
        "PNGQUANT_SOURCE_URL=$pngquantUrl",
        "PNGQUANT_ARCHIVE_SHA256=$actualPngquantArchiveHash",
        'PNGQUANT_ROLE=OCRmyPDF optimize levels 2 and 3'
    )
    Set-Content -LiteralPath $provenance -Encoding ascii -Value $existingProvenance

    $existingSha = @(Get-Content -LiteralPath $shaFile | Where-Object { $_ -notmatch '(?i)\.\./bin/(unpaper\.exe|LIBBZ2-1\.DLL|LIBWINPTHREAD-1\.DLL|ZLIB1\.DLL|pngquant\.exe)\s*$' })
    foreach ($name in @($unpaperRuntimeFiles + 'pngquant.exe')) {
        $file = Join-Path $binRoot $name
        $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
        $existingSha += "$hash  ../bin/$name"
    }
    Set-Content -LiteralPath $shaFile -Encoding ascii -Value $existingSha

    $auxProvenance = Join-Path $binRoot 'OCR_AUX_PROVENANCE.txt'
    Set-Content -LiteralPath $auxProvenance -Encoding ascii -Value @(
        'NAME=PDF_Tunner OCRmyPDF auxiliary native tools',
        "UNPAPER_VERSION=$unpaperVersion",
        "UNPAPER_SOURCE_URL=$unpaperUrl",
        "UNPAPER_ARCHIVE_SHA256=$actualUnpaperArchiveHash",
        'UNPAPER_PROVENANCE=community Windows x86_64 build because upstream 7.0.0 publishes no Windows binary asset',
        "PNGQUANT_VERSION=$pngquantVersion",
        "PNGQUANT_SOURCE_URL=$pngquantUrl",
        "PNGQUANT_ARCHIVE_SHA256=$actualPngquantArchiveHash",
        'VALIDATION=package-first PATH; AMD64 PE; OCRmyPDF ToolProbe; exact OCRmyPDF unpaper/pngquant wrappers; OCRmyPDF --clean + --clean-final; relocated path with spaces'
    )

    Write-Host "Staged and validated OCR auxiliaries: unpaper $unpaperVersion + pngquant $pngquantVersion."
    Write-Host "unpaper archive SHA-256: $actualUnpaperArchiveHash"
    Write-Host "pngquant archive SHA-256: $actualPngquantArchiveHash"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
