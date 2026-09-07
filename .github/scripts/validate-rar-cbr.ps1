param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$BackendBaseUrl,
    [Parameter(Mandatory = $true)][string]$ProbeExecutable,
    [Parameter(Mandatory = $true)][string]$FixtureUrl,
    [Parameter(Mandatory = $true)][string]$FixtureSha256
)

$ErrorActionPreference = 'Stop'
$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$rarDir = Join-Path $portable 'tools/rar'
$rarExe = Join-Path $rarDir 'rar.exe'
$probeSource = (Resolve-Path -LiteralPath $ProbeExecutable).Path
$tempRoot = Join-Path $portable 'data/tmp/rar-cbr-validation'
$probeLog = Join-Path $portable 'data/tmp/rar-cbr-probe.log'
$fixture = Join-Path $tempRoot 'testfile.rar3.cbr'
$pdf = Join-Path $tempRoot 'from-cbr.pdf'
$probeCbr = Join-Path $tempRoot 'probe-output.cbr'
$qpdf = Join-Path $portable 'tools/qpdf/bin/qpdf.exe'

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tempRoot, $rarDir | Out-Null
Remove-Item -LiteralPath $rarExe, $probeLog -Force -ErrorAction SilentlyContinue

try {
    # CBR -> PDF must be genuinely portable and must not rely on any RAR encoder.
    Invoke-WebRequest -Uri $FixtureUrl -OutFile $fixture -UseBasicParsing
    $actualFixtureSha = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualFixtureSha -ne $FixtureSha256.ToLowerInvariant()) {
        throw "CBR fixture SHA-256 mismatch: expected $FixtureSha256, got $actualFixtureSha."
    }
    if (Test-Path -LiteralPath $rarExe) {
        throw 'RAR encoder unexpectedly exists before the CBR->PDF portability test.'
    }

    Invoke-WebRequest `
        -Uri "$BackendBaseUrl/api/v1/convert/cbr/pdf" `
        -Method Post `
        -Form @{ fileInput = Get-Item -LiteralPath $fixture; optimizeForEbook = 'false' } `
        -OutFile $pdf `
        -UseBasicParsing

    $header = [System.IO.File]::ReadAllBytes($pdf)[0..4]
    if ([System.Text.Encoding]::ASCII.GetString($header) -ne '%PDF-') {
        throw 'CBR->PDF did not return a PDF payload.'
    }
    if (-not (Test-Path -LiteralPath $qpdf -PathType Leaf)) {
        throw "Packaged qpdf is unavailable for CBR->PDF verification: $qpdf"
    }
    & $qpdf --check $pdf | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged qpdf rejected the real CBR->PDF output with exit code $LASTEXITCODE."
    }
    Write-Host 'PASS: real RAR3/CBR fixture converted to a valid PDF with no rar.exe present.'

    # PDF -> CBR is conditional. The CI-only probe proves package-first resolution and the
    # exact Stirling arguments without pretending to be a real RAR encoder.
    Copy-Item -LiteralPath $probeSource -Destination $rarExe -Force
    Remove-Item -LiteralPath $probeLog -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest `
        -Uri "$BackendBaseUrl/api/v1/convert/pdf/cbr" `
        -Method Post `
        -Form @{ fileInput = Get-Item -LiteralPath $pdf; dpi = '72' } `
        -OutFile $probeCbr `
        -UseBasicParsing

    $probeMarker = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($probeCbr))
    if ($probeMarker -ne "PDF_TUNNER_RAR_PROBE_ONLY`n") {
        throw 'PDF->CBR response did not come from the CI-only RAR probe.'
    }
    if (-not (Test-Path -LiteralPath $probeLog -PathType Leaf)) {
        throw 'RAR probe was not invoked by the Stirling backend.'
    }
    $probeLines = Get-Content -LiteralPath $probeLog
    $expectedExe = (Resolve-Path -LiteralPath $rarExe).Path
    $actualExe = (($probeLines | Where-Object { $_ -like 'EXE=*' } | Select-Object -First 1) -replace '^EXE=', '')
    if (-not $actualExe -or -not [System.IO.Path]::GetFullPath($actualExe).Equals($expectedExe, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "RAR probe resolved outside package-first tools/rar: expected $expectedExe, got $actualExe."
    }
    foreach ($expected in @('ARG_0=a', 'ARG_1=-m5', 'ARG_2=-ep1')) {
        if ($probeLines -notcontains $expected) {
            throw "RAR probe did not receive expected argument: $expected"
        }
    }
    $outputArg = (($probeLines | Where-Object { $_ -like 'ARG_3=*' } | Select-Object -First 1) -replace '^ARG_3=', '')
    if (-not $outputArg -or [System.IO.Path]::GetExtension($outputArg) -ine '.cbr') {
        throw "RAR probe output argument is not .cbr: $outputArg"
    }
    $pageArgs = @($probeLines | Where-Object { $_ -match '^ARG_[4-9][0-9]*=' })
    if ($pageArgs.Count -lt 1 -or @($pageArgs | Where-Object { $_ -notmatch '(?i)\.png$' }).Count -gt 0) {
        throw 'RAR probe did not receive one or more rendered PNG page inputs.'
    }
    Write-Host 'PASS: PDF->CBR resolved package-local tools/rar/rar.exe and invoked: rar a -m5 -ep1 <output.cbr> <page PNGs>.'

    # Remove the probe and prove Stirling does not fake CBR creation when no licensed encoder exists.
    Remove-Item -LiteralPath $rarExe -Force
    $noRarResponse = Invoke-WebRequest `
        -Uri "$BackendBaseUrl/api/v1/convert/pdf/cbr" `
        -Method Post `
        -Form @{ fileInput = Get-Item -LiteralPath $pdf; dpi = '72' } `
        -SkipHttpErrorCheck `
        -UseBasicParsing
    if ($noRarResponse.StatusCode -lt 400) {
        throw "PDF->CBR unexpectedly succeeded without rar.exe (HTTP $($noRarResponse.StatusCode))."
    }
    Write-Host "PASS: PDF->CBR fails explicitly without rar.exe (HTTP $($noRarResponse.StatusCode)); no ZIP-as-CBR fallback exists."
}
finally {
    Remove-Item -LiteralPath $rarExe, $probeLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$leakedRar = @(Get-ChildItem -LiteralPath $portable -Recurse -Force -File -Filter 'rar.exe' -ErrorAction SilentlyContinue)
if ($leakedRar.Count -gt 0) {
    $leakedRar | Select-Object FullName, Length | Format-Table -AutoSize
    throw 'CI-only rar.exe probe leaked into the portable package.'
}
Write-Host 'PASS: RAR/CBR validation completed and no rar.exe is bundled in PDF_Tunner.'
