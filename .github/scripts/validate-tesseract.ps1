[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedInstallerSha256,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$TessdataCommit,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$EngBlobSha,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$SpaBlobSha,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$OsdBlobSha,

    [string]$BackendLogRoot,

    [switch]$RequireBackendProbe
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "Not a valid PE/MZ executable: $Path"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length) {
        throw "Invalid PE header offset in $Path"
    }
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or $bytes[$peOffset + 2] -ne 0x00 -or $bytes[$peOffset + 3] -ne 0x00) {
        throw "Missing PE signature in $Path"
    }
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

function Get-GitBlobSha1 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $header = [System.Text.Encoding]::UTF8.GetBytes("blob $($bytes.Length)`0")
    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash([System.Security.Cryptography.HashAlgorithmName]::SHA1)
    try {
        $hash.AppendData($header)
        $hash.AppendData($bytes)
        return ([Convert]::ToHexString($hash.GetHashAndReset())).ToLowerInvariant()
    }
    finally { $hash.Dispose() }
}

function New-OcrFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [switch]$Rotate90
    )

    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object System.Drawing.Bitmap 1800, 1100
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $font = New-Object System.Drawing.Font('Arial', 48, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $y = 40
        foreach ($line in $Lines) {
            $graphics.DrawString($line, $font, [System.Drawing.Brushes]::Black, 40, $y)
            $y += 78
        }
        if ($Rotate90) { $bitmap.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $font.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$tesseractRoot = Join-Path $portable 'tools\tesseract'
$tessdataRoot = Join-Path $tesseractRoot 'tessdata'
$exe = Join-Path $tesseractRoot 'tesseract.exe'
$versionFile = Join-Path $tesseractRoot 'version.txt'
$provenanceFile = Join-Path $tesseractRoot 'PROVENANCE.txt'
$shaFile = Join-Path $tesseractRoot 'SHA256SUMS.txt'
$eng = Join-Path $tessdataRoot 'eng.traineddata'
$spa = Join-Path $tessdataRoot 'spa.traineddata'
$osd = Join-Path $tessdataRoot 'osd.traineddata'

foreach ($path in @($exe, $versionFile, $provenanceFile, $shaFile, $eng, $spa, $osd)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Tesseract package file is missing: $path"
    }
}

$recordedVersion = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($recordedVersion -ne $Version) {
    throw "Tesseract version.txt mismatch: expected $Version, got '$recordedVersion'."
}

$metadata = Get-KeyValueMetadata -Path $provenanceFile
$requiredMetadata = @{
    'NAME' = 'Tesseract OCR'
    'VERSION' = $Version
    'PACKAGE_VARIANT' = 'official-win64-nsis'
    'INSTALLER_SHA256' = $ExpectedInstallerSha256.ToLowerInvariant()
    'TESSDATA_REPOSITORY' = 'https://github.com/tesseract-ocr/tessdata_fast'
    'TESSDATA_COMMIT' = $TessdataCommit.ToLowerInvariant()
    'TESSDATA_LANGUAGES' = 'eng,spa,osd'
    'TESSDATA_ENG_GIT_BLOB' = $EngBlobSha.ToLowerInvariant()
    'TESSDATA_SPA_GIT_BLOB' = $SpaBlobSha.ToLowerInvariant()
    'TESSDATA_OSD_GIT_BLOB' = $OsdBlobSha.ToLowerInvariant()
}
foreach ($key in $requiredMetadata.Keys) {
    if (-not $metadata.ContainsKey($key)) { throw "Tesseract provenance is missing $key." }
    if ($metadata[$key].ToLowerInvariant() -ne $requiredMetadata[$key].ToLowerInvariant()) {
        throw "Tesseract provenance mismatch for ${key}: expected '$($requiredMetadata[$key])', got '$($metadata[$key])'."
    }
}

$machine = Get-PeMachine -Path $exe
if ($machine -ne 0x8664) {
    throw ('Packaged tesseract.exe is not AMD64: machine=0x{0:X4}' -f $machine)
}

$modelBlobs = @{
    'eng' = (Get-GitBlobSha1 -Path $eng)
    'spa' = (Get-GitBlobSha1 -Path $spa)
    'osd' = (Get-GitBlobSha1 -Path $osd)
}
if ($modelBlobs['eng'] -ne $EngBlobSha.ToLowerInvariant()) { throw 'eng.traineddata Git blob SHA mismatch.' }
if ($modelBlobs['spa'] -ne $SpaBlobSha.ToLowerInvariant()) { throw 'spa.traineddata Git blob SHA mismatch.' }
if ($modelBlobs['osd'] -ne $OsdBlobSha.ToLowerInvariant()) { throw 'osd.traineddata Git blob SHA mismatch.' }

$shaText = Get-Content -LiteralPath $shaFile -Raw
$exeHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($shaText -notmatch "(?im)^$exeHash\s+tesseract\.exe\s*$") { throw 'Tesseract SHA256SUMS.txt does not contain tesseract.exe hash.' }
foreach ($name in @('eng','spa','osd')) {
    $path = Join-Path $tessdataRoot "$name.traineddata"
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($shaText -notmatch "(?im)^$hash\s+tessdata/$name\.traineddata\s*$") {
        throw "Tesseract SHA256SUMS.txt does not contain $name.traineddata hash."
    }
}

$leakedInstallers = @(Get-ChildItem -LiteralPath $tesseractRoot -Recurse -Force -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^tesseract-ocr-w64-setup-.*\.exe$' -or $_.Name -ieq 'tesseract-win64.exe' })
if ($leakedInstallers.Count -gt 0) {
    $leakedInstallers | Select-Object FullName, Length | Format-Table -AutoSize
    throw 'Downloaded Tesseract installer is present inside the portable product tree.'
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-tesseract-validation-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$engImage = Join-Path $tempRoot 'eng.png'
$spaImage = Join-Path $tempRoot 'spa.png'
$osdImage = Join-Path $tempRoot 'osd.png'
$engOut = Join-Path $tempRoot 'eng-out'
$spaOut = Join-Path $tempRoot 'spa-out'

$oldPath = $env:PATH
$oldTessdataPrefix = $env:TESSDATA_PREFIX
try {
    $system32 = Join-Path $env:SystemRoot 'System32'
    $env:PATH = "$tesseractRoot;$system32;$env:SystemRoot"
    $env:TESSDATA_PREFIX = $tessdataRoot

    $whereOutput = @(& where.exe tesseract 2>&1)
    if ($LASTEXITCODE -ne 0 -or $whereOutput.Count -eq 0) { throw 'where.exe tesseract did not resolve packaged Tesseract.' }
    $resolved = [System.IO.Path]::GetFullPath(($whereOutput[0] | Out-String).Trim())
    if ($resolved -ne [System.IO.Path]::GetFullPath($exe)) {
        throw "Isolated PATH resolved tesseract outside the portable package: $resolved"
    }

    $versionOutput = @(& tesseract --version 2>&1)
    if ($LASTEXITCODE -ne 0 -or $versionOutput.Count -eq 0) { throw "Packaged tesseract --version failed with exit code $LASTEXITCODE." }
    $firstLine = ($versionOutput[0] | Out-String).Trim()
    if ($firstLine -notmatch ('^tesseract\s+' + [Regex]::Escape($Version) + '(\s|$)')) {
        throw "Packaged Tesseract version mismatch: expected $Version, got '$firstLine'."
    }

    $languages = @(& tesseract --list-langs 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Packaged tesseract --list-langs failed with exit code $LASTEXITCODE." }
    foreach ($required in @('eng','spa','osd')) {
        if (-not ($languages -contains $required)) { throw "Packaged Tesseract language list is missing '$required'." }
    }

    New-OcrFixture -Path $engImage -Lines @('PDF TUNNER OCR 2026')
    & tesseract $engImage $engOut -l eng --psm 6 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "English Tesseract OCR failed with exit code $LASTEXITCODE." }
    $engText = ((Get-Content -LiteralPath "$engOut.txt" -Raw) -replace '[^A-Za-z0-9]+',' ').Trim().ToUpperInvariant()
    if ($engText -notlike '*PDF TUNNER OCR 2026*') { throw "English OCR output did not contain expected text: '$engText'" }

    New-OcrFixture -Path $spaImage -Lines @('PRUEBA OCR ESPANOL 2026')
    & tesseract $spaImage $spaOut -l spa --psm 6 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Spanish Tesseract OCR failed with exit code $LASTEXITCODE." }
    $spaText = ((Get-Content -LiteralPath "$spaOut.txt" -Raw) -replace '[^A-Za-z0-9]+',' ').Trim().ToUpperInvariant()
    if ($spaText -notlike '*PRUEBA OCR ESPANOL 2026*') { throw "Spanish OCR output did not contain expected text: '$spaText'" }

    $osdLines = 1..11 | ForEach-Object { "PDF TUNNER ORIENTATION DETECTION DOCUMENT LINE $_ 2026" }
    New-OcrFixture -Path $osdImage -Lines $osdLines -Rotate90
    $osdOutput = @(& tesseract $osdImage stdout -l osd --psm 0 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $osdOutput | Out-Host
        throw "Tesseract OSD validation failed with exit code $LASTEXITCODE."
    }
    $osdText = ($osdOutput -join "`n")
    if ($osdText -notmatch '(?im)^Orientation in degrees:\s*(0|90|180|270)\s*$') {
        throw "OSD output did not report a valid orientation. Output:`n$osdText"
    }
}
finally {
    $env:PATH = $oldPath
    if ($null -eq $oldTessdataPrefix) { Remove-Item Env:TESSDATA_PREFIX -ErrorAction SilentlyContinue } else { $env:TESSDATA_PREFIX = $oldTessdataPrefix }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($RequireBackendProbe) {
    if ([string]::IsNullOrWhiteSpace($BackendLogRoot)) { throw 'RequireBackendProbe requires BackendLogRoot.' }
    if (-not (Test-Path -LiteralPath $BackendLogRoot -PathType Container)) { throw "Backend log root does not exist: $BackendLogRoot" }
    $logs = @(Get-ChildItem -LiteralPath $BackendLogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
    if ($logs.Count -eq 0) { throw "No backend logs were found under $BackendLogRoot." }
    $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
    if ($logText -match '(?im)Missing dependency:\s*tesseract\b') {
        throw 'Stirling runtime dependency checker reported Missing dependency: tesseract.'
    }
    $expectedTessdata = [Regex]::Escape($tessdataRoot)
    if ($logText -notmatch "(?im)Using Tesseract data path:\s*$expectedTessdata") {
        throw "Stirling backend logs did not confirm package-local Tesseract data path: $tessdataRoot"
    }
    Write-Host 'Stirling backend accepted Tesseract and confirmed the package-local tessdata path.'
}

Write-Host "PASS: packaged Tesseract $Version is AMD64, provenance/model pins verified, resolves package-locally, and completed English + Spanish OCR plus OSD functional validation."
