[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [string]$BackendBaseUrl,
    [string]$BackendLogRoot,
    [switch]$RequireRelocation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$fontRelease = 'Noto Sans CJK 2.004'
$fonts = @(
    [pscustomobject]@{ Locale = 'SC'; Family = 'Noto Sans SC'; File = 'NotoSansSC-Regular.otf'; Sha256 = 'faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9'; Text = '简体中文转换测试' },
    [pscustomobject]@{ Locale = 'TC'; Family = 'Noto Sans TC'; File = 'NotoSansTC-Regular.otf'; Sha256 = '5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537'; Text = '繁體中文轉換測試' },
    [pscustomobject]@{ Locale = 'HK'; Family = 'Noto Sans HK'; File = 'NotoSansHK-Regular.otf'; Sha256 = '8a43afea92bb58dfd9027bd7ac6f5b0b2662e2ffb3e7c1edc02c62b2b21924f1'; Text = '香港繁體中文轉換測試' },
    [pscustomobject]@{ Locale = 'JP'; Family = 'Noto Sans JP'; File = 'NotoSansJP-Regular.otf'; Sha256 = 'dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073'; Text = '日本語変換テスト' },
    [pscustomobject]@{ Locale = 'KR'; Family = 'Noto Sans KR'; File = 'NotoSansKR-Regular.otf'; Sha256 = '69975a0ac8472717870aefeab0a4d52739308d90856b9955313b2ad5e0148d68'; Text = '한국어 변환 테스트' }
)

function Get-FileUri {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.Uri][System.IO.Path]::GetFullPath($Path)).AbsoluteUri
}

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [hashtable]$EnvironmentOverrides = @{}
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    foreach ($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }
    foreach ($key in $EnvironmentOverrides.Keys) { $psi.Environment[$key] = [string]$EnvironmentOverrides[$key] }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw "Failed to start $FilePath" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout.Trim(); StdErr = $stderr.Trim(); Output = (($stdout + [Environment]::NewLine + $stderr).Trim()) }
}

function New-FontDocx {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ScratchRoot
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $scratch = Join-Path $ScratchRoot ("font-docx-" + [Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $scratch '_rels'), (Join-Path $scratch 'word') | Out-Null
        @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@.Trim() | Set-Content -LiteralPath (Join-Path $scratch '[Content_Types].xml') -Encoding utf8
        @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@.Trim() | Set-Content -LiteralPath (Join-Path $scratch '_rels\.rels') -Encoding utf8

        $paragraphs = @(
            [pscustomobject]@{ Family = 'Carlito'; Text = 'PDF_Tunner Carlito conversion-font baseline' },
            [pscustomobject]@{ Family = 'Caladea'; Text = 'PDF_Tunner Caladea conversion-font baseline' },
            [pscustomobject]@{ Family = 'DejaVu Sans'; Text = 'PDF_Tunner DejaVu Sans conversion-font baseline' },
            [pscustomobject]@{ Family = 'Liberation Sans'; Text = 'PDF_Tunner Liberation Sans conversion-font baseline' }
        ) + @($fonts | ForEach-Object { [pscustomobject]@{ Family = $_.Family; Text = $_.Text } })
        $runs = foreach ($item in $paragraphs) {
            $family = [System.Security.SecurityElement]::Escape($item.Family)
            $text = [System.Security.SecurityElement]::Escape($item.Text)
            '<w:p><w:r><w:rPr><w:rFonts w:ascii="{0}" w:hAnsi="{0}" w:eastAsia="{0}" w:cs="{0}"/></w:rPr><w:t>{1}</w:t></w:r></w:p>' -f $family, $text
        }
        $document = @(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
            '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>',
            ($runs -join "`n"),
            '<w:sectPr/></w:body></w:document>'
        ) -join "`n"
        $document | Set-Content -LiteralPath (Join-Path $scratch 'word\document.xml') -Encoding utf8
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::CreateFromDirectory($scratch, $Path)
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-FontPayload {
    param([Parameter(Mandatory = $true)][string]$Root)
    $libreFontRoot = Join-Path $Root 'tools\libreoffice\share\fonts\truetype'
    $metadataRoot = Join-Path $Root 'tools\fonts'
    foreach ($required in @((Join-Path $metadataRoot 'VERSION.txt'), (Join-Path $metadataRoot 'PROVENANCE.txt'), (Join-Path $metadataRoot 'SHA256SUMS.txt'))) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Conversion-font metadata is missing: $required" }
    }
    foreach ($font in $fonts) {
        $path = Join-Path $libreFontRoot $font.File
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Packaged CJK conversion font is missing: $path" }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $font.Sha256) { throw "$($font.File) SHA-256 mismatch: expected $($font.Sha256), got $actual." }
    }
    foreach ($pattern in @('Carlito*Regular*.ttf','Caladea*Regular*.ttf','DejaVuSans*.ttf','LiberationSans*Regular*.ttf')) {
        if (-not (Get-ChildItem -LiteralPath $libreFontRoot -Recurse -Force -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            throw "Accepted LibreOffice runtime no longer contains conversion-font baseline matching '$pattern'."
        }
    }
}

function Assert-NoHostCjkCopies {
    $hostRoots = @((Join-Path $env:SystemRoot 'Fonts'), (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts')) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }
    foreach ($font in $fonts) {
        foreach ($root in $hostRoots) {
            $matches = @(Get-ChildItem -LiteralPath $root -Force -File -Filter $font.File -ErrorAction SilentlyContinue)
            if ($matches.Count -gt 0) { throw "Host Windows font could satisfy the CJK gate accidentally: $($matches.FullName -join ', ')" }
        }
    }
}

function Assert-PdfFontContract {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Pdf
    )
    $poppler = Join-Path $Root 'tools\poppler\Library\bin'
    $pdffonts = Join-Path $poppler 'pdffonts.exe'
    $pdftotext = Join-Path $poppler 'pdftotext.exe'
    foreach ($tool in @($pdffonts, $pdftotext)) {
        if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Accepted Poppler runtime is missing font-validation tool: $tool" }
    }
    $fontOutput = Invoke-CapturedProcess -FilePath $pdffonts -Arguments @($Pdf)
    if ($fontOutput.ExitCode -ne 0) { throw "pdffonts failed for conversion-font PDF: $($fontOutput.Output)" }
    foreach ($font in $fonts) {
        $fileStem = [Regex]::Escape(([System.IO.Path]::GetFileNameWithoutExtension($font.File) -replace '-Regular$',''))
        if ($fontOutput.Output -notmatch "(?i)$fileStem") {
            throw "Converted PDF did not embed the requested package-local $($font.Family) face. pdffonts output: $($fontOutput.Output)"
        }
    }
    foreach ($baseline in @('Carlito','Caladea','DejaVu','Liberation')) {
        if ($fontOutput.Output -notmatch "(?i)$baseline") {
            throw "Converted PDF did not preserve the expected LibreOffice bundled $baseline font baseline. pdffonts output: $($fontOutput.Output)"
        }
    }

    $textPath = "$Pdf.txt"
    Remove-Item -LiteralPath $textPath -Force -ErrorAction SilentlyContinue
    $textResult = Invoke-CapturedProcess -FilePath $pdftotext -Arguments @('-enc','UTF-8',$Pdf,$textPath)
    if ($textResult.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $textPath -PathType Leaf)) { throw "pdftotext failed for conversion-font PDF: $($textResult.Output)" }
    $text = Get-Content -LiteralPath $textPath -Raw -Encoding utf8
    foreach ($font in $fonts) {
        if ($text -notlike "*$($font.Text)*") { throw "Converted PDF lost CJK text for $($font.Family): '$($font.Text)'" }
    }
    Remove-Item -LiteralPath $textPath -Force -ErrorAction SilentlyContinue
}

function Invoke-DirectFontConversion {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
    Assert-FontPayload -Root $Root
    Assert-NoHostCjkCopies
    $soffice = Join-Path $Root 'tools\libreoffice\program\soffice.com'
    $work = Join-Path $Root ("data\tmp\conversion-fonts-" + $Label)
    $profile = Join-Path $work 'profile'
    $out = Join-Path $work 'out'
    $nativeTemp = Join-Path $Root 'data\tmp\libreoffice'
    $docx = Join-Path $work 'font-contract.docx'
    $pdf = Join-Path $out 'font-contract.pdf'
    try {
        New-Item -ItemType Directory -Force -Path $work, $profile, $out, $nativeTemp | Out-Null
        New-FontDocx -Path $docx -ScratchRoot $work
        $result = Invoke-CapturedProcess -FilePath $soffice -Arguments @(
            ('-env:UserInstallation=' + (Get-FileUri -Path $profile)), '--headless','--nologo','--convert-to','pdf','--outdir',$out,$docx
        ) -EnvironmentOverrides @{ TEMP = $nativeTemp; TMP = $nativeTemp }
        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pdf -PathType Leaf)) { throw "LibreOffice conversion-font DOCX->PDF failed ($Label): $($result.Output)" }
        if ((Get-Item -LiteralPath $pdf).Length -lt 1000) { throw "Conversion-font PDF is unexpectedly small ($Label)." }
        Assert-PdfFontContract -Root $Root -Pdf $pdf
        Write-Host "PASS: direct LibreOffice conversion embedded five package-local Noto CJK Regular faces plus bundled Latin baseline ($Label)."
    }
    finally {
        Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-BackendFontConversion {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$LogRoot
    )
    $systemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot')
    $curl = Join-Path $systemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { throw "Windows curl.exe is unavailable: $curl" }
    $work = Join-Path $Root 'data\tmp\conversion-fonts-backend'
    $docx = Join-Path $work 'backend-font-contract.docx'
    $pdf = Join-Path $work 'backend-font-contract.pdf'
    $headers = "$pdf.headers"
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    New-FontDocx -Path $docx -ScratchRoot $work
    $result = Invoke-CapturedProcess -FilePath $curl -Arguments @(
        '--silent','--show-error','--fail-with-body','--connect-timeout','15','--max-time','180','--request','POST',
        '--form',("fileInput=@{0};type=application/vnd.openxmlformats-officedocument.wordprocessingml.document" -f $docx),
        '--output',$pdf,'--dump-header',$headers,'--write-out','%{http_code}',($BaseUrl.TrimEnd('/') + '/api/v1/convert/file/pdf')
    )
    if ($result.ExitCode -ne 0 -or $result.StdOut -ne '200') { throw "Real Stirling conversion-font API probe failed (curl exit $($result.ExitCode), HTTP '$($result.StdOut)'): $($result.StdErr)" }
    Assert-PdfFontContract -Root $Root -Pdf $pdf
    if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) { throw "Backend log root is missing: $LogRoot" }
    $logs = @(Get-ChildItem -LiteralPath $LogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
    $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
    if ($logText -match '(?im)Missing dependency:\s*(soffice|unoconvert)\b') { throw 'Backend reported a LibreOffice dependency failure during CJK conversion.' }
    Write-Host 'PASS: real Stirling Office->PDF route preserved all five package-local CJK font families and text.'
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
Assert-FontPayload -Root $portable
Invoke-DirectFontConversion -Root $portable -Label 'source'

if ($RequireRelocation) {
    $temporaryParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
    $container = Join-Path $temporaryParent ("PDF_Tunner conversion fonts relocation " + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $rootA = Join-Path $container 'Portable Fonts With Spaces'
    $rootB = Join-Path $container 'Portable Fonts Moved Again'
    try {
        New-Item -ItemType Directory -Force -Path $container | Out-Null
        Move-Item -LiteralPath $portable -Destination $rootA
        Invoke-DirectFontConversion -Root $rootA -Label 'relocated-a'
        Move-Item -LiteralPath $rootA -Destination $rootB
        Invoke-DirectFontConversion -Root $rootB -Label 'relocated-b'
        Write-Host "PASS: conversion-font layer survived package relocation: '$rootA' -> '$rootB'."
    }
    finally {
        if (-not (Test-Path -LiteralPath $portable -PathType Container)) {
            if (Test-Path -LiteralPath $rootB -PathType Container) { Move-Item -LiteralPath $rootB -Destination $portable }
            elseif (Test-Path -LiteralPath $rootA -PathType Container) { Move-Item -LiteralPath $rootA -Destination $portable }
        }
        if (Test-Path -LiteralPath $portable -PathType Container) { Remove-Item -LiteralPath $container -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

if (-not [string]::IsNullOrWhiteSpace($BackendBaseUrl) -or -not [string]::IsNullOrWhiteSpace($BackendLogRoot)) {
    if ([string]::IsNullOrWhiteSpace($BackendBaseUrl) -or [string]::IsNullOrWhiteSpace($BackendLogRoot)) { throw 'BackendBaseUrl and BackendLogRoot must be supplied together for the conversion-font backend gate.' }
    Invoke-BackendFontConversion -Root $portable -BaseUrl $BackendBaseUrl -LogRoot $BackendLogRoot
}

Write-Host "PASS: $fontRelease package-local conversion-font validation completed."
