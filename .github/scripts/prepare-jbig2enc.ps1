[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$jbig2Version = '0.32'
$jbig2Tag = '0.32'
$jbig2Commit = '309b2d55c7dfdcf0ab6afccb6d88834afc0bf2c0'
$jbig2Repository = 'https://github.com/agl/jbig2enc.git'
$mesonVersion = '1.10.0'
$mesonWheelUrl = 'https://files.pythonhosted.org/packages/32/4f/c398c6f06ece1c6c246e008d5dac3824c98f54d3eb3d8014f4910afd6d48/meson-1.10.0-py3-none-any.whl'
$mesonWheelSha256 = '4b27aafce281e652dcb437b28007457411245d975c48b5db3a797d3e93ae1585'
$expectedOcrMyPdfVersion = '17.10.0'

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

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw "Not a valid PE/MZ executable: $Path" }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length) { throw "Invalid PE header offset in $Path" }
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) { throw "Missing PE signature in $Path" }
    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

function Invoke-CheckedNative {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )
    & $FilePath @Arguments 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Test-Jbig2Runtime {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$PythonRoot,
        [switch]$RunOptimizeE2E
    )

    $jbig2Root = Join-Path $Root 'tools\jbig2enc'
    $jbig2 = Join-Path $jbig2Root 'jbig2.exe'
    $python = Join-Path $PythonRoot 'python.exe'
    $ocr = Join-Path $PythonRoot 'ocrmypdf.exe'
    foreach ($path in @($jbig2, $python, $ocr)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required jbig2enc/OCRmyPDF runtime file is missing: $path" }
    }
    if ((Get-PeMachine -Path $jbig2) -ne 0x8664) { throw "Bundled jbig2.exe is not AMD64: $jbig2" }

    $oldPath = $env:PATH
    $oldTessdata = $env:TESSDATA_PREFIX
    try {
        $system32 = Join-Path $env:SystemRoot 'System32'

        # First prove jbig2.exe itself runs without Python, Visual Studio, MSYS2 or
        # another package directory on PATH. The build uses Meson's static MSVC CRT.
        $env:PATH = "$jbig2Root;$system32;$env:SystemRoot"
        $whereJbig2 = @(& where.exe jbig2 2>&1)
        if ($LASTEXITCODE -ne 0 -or $whereJbig2.Count -eq 0) { throw 'where.exe jbig2 failed in isolated standalone PATH.' }
        $resolvedJbig2 = [System.IO.Path]::GetFullPath(($whereJbig2[0] | Out-String).Trim())
        $expectedJbig2 = [System.IO.Path]::GetFullPath($jbig2)
        if ($resolvedJbig2 -ne $expectedJbig2) { throw "Standalone PATH resolved jbig2 outside package: $resolvedJbig2 (expected $expectedJbig2)." }
        $versionOutput = (@(& jbig2 -V 2>&1) -join ' ').Trim()
        if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "(?i)jbig2enc\s+$([Regex]::Escape($jbig2Version))(?:\s|$)") {
            throw "jbig2enc version validation failed: '$versionOutput'."
        }

        # Then add only the package-local Python runtime and prove OCRmyPDF's exact
        # ToolProbe resolves this jbig2 binary rather than a TeX Live/host conflict.
        $env:PATH = "$jbig2Root;$PythonRoot;$system32;$env:SystemRoot"
        $ocrVersion = (@(& $ocr --version 2>&1) -join ' ').Trim()
        if ($LASTEXITCODE -ne 0 -or $ocrVersion -ne $expectedOcrMyPdfVersion) {
            throw "jbig2enc gate expected OCRmyPDF $expectedOcrMyPdfVersion, got '$ocrVersion'."
        }
        $probe = @(& $python -c "from ocrmypdf._exec import jbig2enc; assert jbig2enc.available(); print(jbig2enc.version())" 2>&1)
        if ($LASTEXITCODE -ne 0) { $probe | Out-Host; throw 'OCRmyPDF did not detect packaged jbig2enc.' }
        $probeText = ($probe -join ' ').Trim()
        if ($probeText -notmatch "(?<!\d)$([Regex]::Escape($jbig2Version))(?!\d)") {
            throw "OCRmyPDF jbig2enc ToolProbe returned unexpected version: '$probeText'."
        }

        if ($RunOptimizeE2E) {
            $ghostscriptRoot = Join-Path $Root 'tools\ghostscript\bin'
            $tesseractRoot = Join-Path $Root 'tools\tesseract'
            $tessdata = Join-Path $tesseractRoot 'tessdata'
            foreach ($required in @((Join-Path $ghostscriptRoot 'gs.exe'), (Join-Path $tesseractRoot 'tesseract.exe'), (Join-Path $tessdata 'eng.traineddata'))) {
                if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required jbig2enc E2E dependency is missing: $required" }
            }
            $env:PATH = "$jbig2Root;$PythonRoot;$ghostscriptRoot;$tesseractRoot;$system32;$env:SystemRoot"
            $env:TESSDATA_PREFIX = $tessdata

            $fixture = Join-Path $Root 'jbig2enc-fixture.png'
            $outputPdf = Join-Path $Root 'jbig2enc-optimized.pdf'
            Remove-Item -LiteralPath $fixture, $outputPdf -Force -ErrorAction SilentlyContinue
            $fixtureProbe = @(& $python -c "from PIL import Image,ImageDraw; import sys; im=Image.new('1',(2400,1600),1); d=ImageDraw.Draw(im); d.rectangle((60,60,2340,1540),outline=0,width=8); [d.rectangle((120,140+i*90, 2200-(i%5)*80, 175+i*90), fill=0) for i in range(14)]; [d.rectangle((160+(i%8)*250, 1450-(i//8)*70, 300+(i%8)*250, 1490-(i//8)*70), fill=0) for i in range(24)]; im.save(sys.argv[1],dpi=(300,300))" $fixture 2>&1)
            if ($LASTEXITCODE -ne 0) { $fixtureProbe | Out-Host; throw 'Failed to create deterministic bilevel jbig2enc OCR fixture.' }

            $ocrOutput = @(& $ocr --verbose 2 --output-type pdf --language eng --jobs 1 --image-dpi 300 --optimize 2 $fixture $outputPdf 2>&1)
            if ($LASTEXITCODE -ne 0) { $ocrOutput | Out-Host; throw "OCRmyPDF --optimize 2 jbig2enc E2E failed with exit code $LASTEXITCODE." }
            if (-not (Test-Path -LiteralPath $outputPdf -PathType Leaf) -or (Get-Item -LiteralPath $outputPdf).Length -lt 1000) {
                throw 'OCRmyPDF --optimize 2 did not produce a valid-sized PDF.'
            }
            $ocrText = ($ocrOutput -join "`n")
            if ($ocrText -match '(?im)program [''"]?jbig2[''"]?.*(could not be executed|not found)') {
                $ocrOutput | Out-Host
                throw 'OCRmyPDF reported packaged jbig2enc unavailable during optimize level 2.'
            }
            $pdfAscii = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($outputPdf))
            if ($pdfAscii -notmatch '/JBIG2Decode\b') {
                $ocrOutput | Out-Host
                throw 'OCRmyPDF --optimize 2 output did not contain a /JBIG2Decode image stream.'
            }
            Remove-Item -LiteralPath $fixture, $outputPdf -Force -ErrorAction SilentlyContinue
            Write-Host 'PASS: OCRmyPDF 17.10.0 --optimize 2 produced a real /JBIG2Decode PDF using packaged jbig2enc.'
        }
    }
    finally {
        $env:PATH = $oldPath
        if ($null -eq $oldTessdata) { Remove-Item Env:TESSDATA_PREFIX -ErrorAction SilentlyContinue } else { $env:TESSDATA_PREFIX = $oldTessdata }
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$pythonRoot = Join-Path $toolsRoot 'python'
$jbig2Root = Join-Path $toolsRoot 'jbig2enc'
$launcherSource = (Resolve-Path -LiteralPath './frontend/editor/src-tauri/src/main.rs').Path
if (-not (Test-Path -LiteralPath $pythonRoot -PathType Container)) { throw "Accepted Python/OCRmyPDF runtime is missing: $pythonRoot" }
$launcherText = Get-Content -LiteralPath $launcherSource -Raw
if ($launcherText -notmatch 'tools\.join\("jbig2enc"\)') {
    throw 'Portable Tauri bootstrap no longer includes tools/jbig2enc in its package-first PATH.'
}

$tempParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$tempRoot = Join-Path $tempParent ("pdf-tunner-jbig2enc-" + [Guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $tempRoot 'source'
$buildRoot = Join-Path $tempRoot 'build'
$installRoot = Join-Path $tempRoot 'install'
$venvRoot = Join-Path $tempRoot 'meson-venv'
$mesonWheel = Join-Path $tempRoot "meson-$mesonVersion-py3-none-any.whl"
$relocationRoot = Join-Path $tempRoot 'Relocated PDF_Tunner JBIG2 With Spaces'

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $git = (Get-Command git.exe -ErrorAction Stop).Source
    $runnerPython = (Get-Command python.exe -ErrorAction Stop).Source

    Write-Host "Fetching pinned jbig2enc $jbig2Version source from $jbig2Repository."
    Invoke-CheckedNative -FilePath $git -Arguments @('clone','--depth','1','--branch',$jbig2Tag,'--single-branch',$jbig2Repository,$sourceRoot) -Label 'jbig2enc source clone'
    $sourceHead = (@(& $git -C $sourceRoot rev-parse HEAD 2>&1) -join '').Trim().ToLowerInvariant()
    if ($LASTEXITCODE -ne 0 -or $sourceHead -ne $jbig2Commit) {
        throw "jbig2enc source identity mismatch: expected $jbig2Commit, got '$sourceHead'."
    }
    $exactTag = (@(& $git -C $sourceRoot describe --tags --exact-match HEAD 2>&1) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $exactTag -ne $jbig2Tag) { throw "jbig2enc exact tag validation failed: '$exactTag'." }

    $wrapFiles = @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'subprojects') -File -Filter '*.wrap' -ErrorAction Stop)
    if ($wrapFiles.Count -lt 1) { throw 'jbig2enc source did not contain Meson wrap dependency locks.' }
    foreach ($wrap in $wrapFiles) {
        $text = Get-Content -LiteralPath $wrap.FullName -Raw
        if ($text -notmatch '(?im)^source_hash\s*=\s*[0-9a-f]{64}\s*$') {
            throw "jbig2enc Meson wrap lacks an authenticated source_hash: $($wrap.Name)"
        }
        if ($text -match '(?im)^patch_url\s*=' -and $text -notmatch '(?im)^patch_hash\s*=\s*[0-9a-f]{64}\s*$') {
            throw "jbig2enc Meson wrap has patch_url without patch_hash: $($wrap.Name)"
        }
    }
    Write-Host "Authenticated Meson wraps found: $($wrapFiles.Count)."

    Write-Host "Downloading pinned Meson $mesonVersion wheel."
    Invoke-WebRequest -Uri $mesonWheelUrl -OutFile $mesonWheel -UseBasicParsing
    $actualMesonHash = Assert-Hash -Path $mesonWheel -Expected $mesonWheelSha256 -Label 'Meson wheel'
    Invoke-CheckedNative -FilePath $runnerPython -Arguments @('-m','venv',$venvRoot) -Label 'Meson virtual environment creation'
    $venvPython = Join-Path $venvRoot 'Scripts\python.exe'
    $meson = Join-Path $venvRoot 'Scripts\meson.exe'
    Invoke-CheckedNative -FilePath $venvPython -Arguments @('-m','pip','install','--disable-pip-version-check','--no-deps',$mesonWheel) -Label 'Pinned Meson installation'

    Push-Location $sourceRoot
    try {
        Invoke-CheckedNative -FilePath $meson -Arguments @('setup','--vsenv','--buildtype','release','-Db_vscrt=mt','-Ddefault_library=static','--wrap-mode=forcefallback','--prefix',$installRoot,'--licensedir','licenses',$buildRoot) -Label 'jbig2enc Meson setup'
        Invoke-CheckedNative -FilePath $meson -Arguments @('compile','-C',$buildRoot) -Label 'jbig2enc Meson compile'
        Invoke-CheckedNative -FilePath $meson -Arguments @('test','-C',$buildRoot,'--print-errorlogs','jbig2enc:') -Label 'jbig2enc upstream Meson tests'
        Invoke-CheckedNative -FilePath $meson -Arguments @('install','-C',$buildRoot) -Label 'jbig2enc Meson install'
    }
    finally {
        Pop-Location
    }

    $builtJbig2 = Join-Path $installRoot 'bin\jbig2.exe'
    if (-not (Test-Path -LiteralPath $builtJbig2 -PathType Leaf)) { throw "jbig2enc install did not produce expected executable: $builtJbig2" }
    if ((Get-PeMachine -Path $builtJbig2) -ne 0x8664) { throw 'Built jbig2.exe is not AMD64.' }

    Remove-Item -LiteralPath $jbig2Root -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $jbig2Root | Out-Null
    Copy-Item -LiteralPath $builtJbig2 -Destination (Join-Path $jbig2Root 'jbig2.exe') -Force
    $installedLicenses = Join-Path $installRoot 'licenses'
    if (-not (Test-Path -LiteralPath $installedLicenses -PathType Container)) { throw 'Meson install did not produce the requested license closure.' }
    $licenseFiles = @(Get-ChildItem -LiteralPath $installedLicenses -Recurse -Force -File -ErrorAction Stop)
    if ($licenseFiles.Count -lt 1) { throw 'Meson license closure is unexpectedly empty.' }
    Copy-Item -LiteralPath $installedLicenses -Destination (Join-Path $jbig2Root 'licenses') -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'COPYING') -Destination (Join-Path $jbig2Root 'COPYING.txt') -Force
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'doc\PATENTS') -Destination (Join-Path $jbig2Root 'PATENTS.txt') -Force

    $jbig2Hash = (Get-FileHash -LiteralPath (Join-Path $jbig2Root 'jbig2.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $jbig2Root 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=jbig2enc',
        "VERSION=$jbig2Version",
        "SOURCE_REPOSITORY=$jbig2Repository",
        "SOURCE_TAG=$jbig2Tag",
        "SOURCE_COMMIT=$jbig2Commit",
        "MESON_VERSION=$mesonVersion",
        "MESON_WHEEL_URL=$mesonWheelUrl",
        "MESON_WHEEL_SHA256=$actualMesonHash",
        "MESON_WRAP_COUNT=$($wrapFiles.Count)",
        "MESON_LICENSE_FILE_COUNT=$($licenseFiles.Count)",
        'BUILD=MSVC x64; Meson release; b_vscrt=mt; default_library=static; wrap-mode=forcefallback; Meson-installed license closure retained',
        "JBIG2_EXE_SHA256=$jbig2Hash",
        'ROLE=OCRmyPDF optimize levels 2 and 3; lossless JBIG2 compression path',
        'VALIDATION=source tag+commit; authenticated Meson wraps; upstream Meson tests; Meson license install; AMD64 PE; standalone isolated PATH; OCRmyPDF ToolProbe; optimize 2 /JBIG2Decode E2E; relocated path with spaces'
    )

    $shaLines = @("$actualMesonHash  BUILD-INPUT meson-$mesonVersion-py3-none-any.whl")
    $jbig2RootPrefix = [System.IO.Path]::GetFullPath($jbig2Root).TrimEnd('\') + '\'
    foreach ($packageFile in @(Get-ChildItem -LiteralPath $jbig2Root -Recurse -Force -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | Sort-Object FullName)) {
        $relative = [System.IO.Path]::GetFullPath($packageFile.FullName).Substring($jbig2RootPrefix.Length).Replace('\','/')
        $hash = (Get-FileHash -LiteralPath $packageFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $shaLines += "$hash  $relative"
    }
    Set-Content -LiteralPath (Join-Path $jbig2Root 'SHA256SUMS.txt') -Encoding ascii -Value $shaLines

    Test-Jbig2Runtime -Root $portable -PythonRoot $pythonRoot -RunOptimizeE2E

    $relocatedJbig2Root = Join-Path $relocationRoot 'tools\jbig2enc'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $relocatedJbig2Root) | Out-Null
    Copy-Item -LiteralPath $jbig2Root -Destination (Split-Path -Parent $relocatedJbig2Root) -Recurse -Force
    Test-Jbig2Runtime -Root $relocationRoot -PythonRoot $pythonRoot
    Write-Host "PASS: jbig2enc remains functional after relocation to '$relocationRoot'."

    Write-Host "Staged jbig2enc $jbig2Version from source commit $jbig2Commit."
    Write-Host "jbig2.exe SHA-256: $jbig2Hash"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
