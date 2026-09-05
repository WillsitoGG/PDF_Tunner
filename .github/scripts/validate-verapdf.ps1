[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$BackendBaseUrl,
    [Parameter(Mandatory = $true)][string]$BackendLogRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$veraPdfVersion = '1.30.2'
$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$logs = (Resolve-Path -LiteralPath $BackendLogRoot).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$buildGradle = Join-Path $repoRoot 'app\core\build.gradle'
$java = Join-Path $portable 'runtime\jre\bin\java.exe'
$work = Join-Path $portable 'data\tmp\verapdf-e2e'
$samplePdf = Join-Path $work 'verapdf-input.pdf'
$pdfa = Join-Path $work 'verapdf-pdfa-2b.pdf'
$pdfaHeaders = Join-Path $work 'verapdf-pdfa-2b.headers'
$verificationJson = Join-Path $work 'verapdf-verification.json'
$verificationHeaders = Join-Path $work 'verapdf-verification.headers'

foreach ($required in @($buildGradle, $java)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "VeraPDF E2E prerequisite is missing: $required"
    }
}
if (-not (Test-Path -LiteralPath $logs -PathType Container)) {
    throw "VeraPDF E2E backend log root is missing: $logs"
}

$buildText = Get-Content -LiteralPath $buildGradle -Raw
$expectedDependency = "org.verapdf:validation-model:$veraPdfVersion"
if ($buildText -notlike "*$expectedDependency*") {
    throw "Pinned Stirling core no longer declares the expected embedded VeraPDF dependency $expectedDependency."
}

$moduleOutput = & $java --list-modules 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "Bundled JRE failed --list-modules while validating VeraPDF runtime support: $moduleOutput"
}
if ($moduleOutput -notmatch '(?m)^jdk\.dynalink@') {
    throw 'Bundled JRE is missing jdk.dynalink, which Stirling requires for embedded VeraPDF.'
}

$systemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot')
$curl = Join-Path $systemRoot 'System32\curl.exe'
if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) {
    throw "Windows curl.exe is unavailable for the VeraPDF API E2E probe: $curl"
}

function New-DeterministicPdfFixture {
    param([Parameter(Mandatory = $true)][string]$Path)

    $ascii = [System.Text.Encoding]::ASCII
    $stream = [System.IO.MemoryStream]::new()
    try {
        $writeAscii = {
            param([Parameter(Mandatory = $true)][string]$Text)
            $bytes = $ascii.GetBytes($Text)
            $stream.Write($bytes, 0, $bytes.Length)
        }

        & $writeAscii "%PDF-1.4`n"

        $content = "q`n0.9 g`n72 72 468 648 re`nf`nQ`n"
        $contentLength = $ascii.GetByteCount($content)
        $objects = @(
            "1 0 obj`n<< /Type /Catalog /Pages 2 0 R >>`nendobj`n",
            "2 0 obj`n<< /Type /Pages /Kids [3 0 R] /Count 1 >>`nendobj`n",
            "3 0 obj`n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << >> /Contents 4 0 R >>`nendobj`n",
            ("4 0 obj`n<< /Length {0} >>`nstream`n{1}endstream`nendobj`n" -f $contentLength, $content)
        )

        $offsets = [System.Collections.Generic.List[long]]::new()
        foreach ($object in $objects) {
            $offsets.Add($stream.Position)
            & $writeAscii $object
        }

        $xrefOffset = $stream.Position
        & $writeAscii "xref`n0 5`n0000000000 65535 f `n"
        foreach ($offset in $offsets) {
            $offsetText = $offset.ToString('D10', [System.Globalization.CultureInfo]::InvariantCulture)
            & $writeAscii ($offsetText + " 00000 n `n")
        }
        & $writeAscii ("trailer`n<< /Size 5 /Root 1 0 R >>`nstartxref`n{0}`n%%EOF`n" -f $xrefOffset)

        [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-CurlProbe {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $curl
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    foreach ($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    if (-not $process.Start()) { throw "Failed to start curl.exe for $Label." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
    $stderr = $stderrTask.GetAwaiter().GetResult().Trim()

    if ($process.ExitCode -ne 0 -or $stdout -ne '200') {
        throw "$Label failed (curl exit $($process.ExitCode), HTTP '$stdout'): $stderr"
    }
}

New-Item -ItemType Directory -Force -Path $work | Out-Null
Remove-Item -LiteralPath $samplePdf, $pdfa, $pdfaHeaders, $verificationJson, $verificationHeaders -Force -ErrorAction SilentlyContinue
New-DeterministicPdfFixture -Path $samplePdf

if (-not (Test-Path -LiteralPath $samplePdf -PathType Leaf)) {
    throw 'Deterministic VeraPDF input fixture was not created.'
}
$sampleBytes = [System.IO.File]::ReadAllBytes($samplePdf)
if ($sampleBytes.Length -lt 300 -or [System.Text.Encoding]::ASCII.GetString($sampleBytes[0..4]) -ne '%PDF-') {
    throw 'Deterministic VeraPDF input fixture is not a valid-looking PDF.'
}
$sampleText = [System.Text.Encoding]::ASCII.GetString($sampleBytes)
if ($sampleText -notmatch '(?s)xref\s+0 5.*startxref\s+\d+\s+%%EOF\s*$') {
    throw 'Deterministic VeraPDF input fixture is missing its xref/startxref/EOF contract.'
}

$base = $BackendBaseUrl.TrimEnd('/')
Invoke-CurlProbe -Label 'Real Stirling PDF/A-2b conversion for VeraPDF E2E' -Arguments @(
    '--silent','--show-error','--fail-with-body','--connect-timeout','15','--max-time','240','--request','POST',
    '--form',("fileInput=@{0};type=application/pdf" -f $samplePdf),
    '--form','outputFormat=pdfa-2b',
    '--form','strict=false',
    '--form','pdfUa=false',
    '--output',$pdfa,
    '--dump-header',$pdfaHeaders,
    '--write-out','%{http_code}',
    ($base + '/api/v1/convert/pdf/pdfa')
)

if (-not (Test-Path -LiteralPath $pdfa -PathType Leaf)) {
    throw 'Stirling PDF/A-2b conversion returned HTTP 200 but produced no PDF.'
}
if ((Get-Item -LiteralPath $pdfa).Length -lt 1000) {
    throw 'Stirling PDF/A-2b conversion produced an unexpectedly small file.'
}
$pdfBytes = [System.IO.File]::ReadAllBytes($pdfa)
if ($pdfBytes.Length -lt 5 -or [System.Text.Encoding]::ASCII.GetString($pdfBytes[0..4]) -ne '%PDF-') {
    throw 'Stirling PDF/A-2b conversion output is not a PDF.'
}

Invoke-CurlProbe -Label 'Real Stirling VeraPDF verification API' -Arguments @(
    '--silent','--show-error','--fail-with-body','--connect-timeout','15','--max-time','240','--request','POST',
    '--form',("fileInput=@{0};type=application/pdf" -f $pdfa),
    '--output',$verificationJson,
    '--dump-header',$verificationHeaders,
    '--write-out','%{http_code}',
    ($base + '/api/v1/security/verify-pdf')
)

if (-not (Test-Path -LiteralPath $verificationJson -PathType Leaf)) {
    throw 'VeraPDF verification returned HTTP 200 but produced no JSON body.'
}
$raw = Get-Content -LiteralPath $verificationJson -Raw -Encoding utf8
try {
    $payload = @($raw | ConvertFrom-Json)
}
catch {
    throw "VeraPDF verification response was not valid JSON: $raw"
}
if ($payload.Count -eq 0) {
    throw "VeraPDF verification returned an empty result array: $raw"
}

$accepted = @($payload | Where-Object {
    $identity = "$(($_.standard)) $(($_.validationProfile)) $(($_.standardName)) $(($_.validationProfileName))"
    $_.declaredPdfa -eq $true -and
    $_.compliant -eq $true -and
    [int]$_.totalFailures -eq 0 -and
    $identity -match '(?i)2\s*-?\s*b|2b'
})
if ($accepted.Count -eq 0) {
    throw "VeraPDF did not report the generated PDF/A-2b as declared, compliant and failure-free. Response: $raw"
}

$logFiles = @(Get-ChildItem -LiteralPath $logs -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
if ($logFiles.Count -eq 0) {
    throw 'No backend logs were available for VeraPDF E2E evidence.'
}
$logText = ($logFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
if ($logText -notmatch '(?im)VeraPDF Greenfield initialized successfully') {
    throw 'Backend logs do not prove successful initialization of embedded VeraPDF Greenfield.'
}
if ($logText -notmatch '(?im)Verification complete for .*standard\(s\) checked') {
    throw 'Backend logs do not prove that the real verify-pdf controller completed VeraPDF validation.'
}

Write-Host "PASS: embedded VeraPDF $veraPdfVersion E2E validated package-local JRE support, deterministic PDF fixture, real PDF/A-2b conversion, /api/v1/security/verify-pdf compliance, and backend execution evidence."
