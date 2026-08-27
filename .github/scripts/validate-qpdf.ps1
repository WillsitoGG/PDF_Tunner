[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedArchiveSha256,

    [string]$SamplePdf,

    [string]$BackendLogRoot,

    [switch]$RequireBackendProbe
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$qpdfRoot = Join-Path $portable 'tools\qpdf'
$qpdfBin = Join-Path $qpdfRoot 'bin'
$qpdfExe = Join-Path $qpdfBin 'qpdf.exe'
$provenance = Join-Path $qpdfRoot 'PROVENANCE.txt'
$checksums = Join-Path $qpdfRoot 'SHA256SUMS.txt'
$versionFile = Join-Path $qpdfRoot 'version.txt'

foreach ($required in @($qpdfExe, $provenance, $checksums, $versionFile)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required packaged qpdf file is missing: $required"
    }
}

$recordedVersion = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($recordedVersion -ne $Version) {
    throw "qpdf version metadata mismatch: expected $Version, got $recordedVersion."
}

$provenanceText = Get-Content -LiteralPath $provenance -Raw
if ($provenanceText -notmatch ('(?m)^VERSION=' + [Regex]::Escape($Version) + '\s*$')) {
    throw "qpdf provenance does not record VERSION=$Version."
}
if ($provenanceText -notmatch '(?m)^ARCHIVE_SHA256=([0-9a-fA-F]{64})\s*$') {
    throw 'qpdf provenance does not contain ARCHIVE_SHA256.'
}
$recordedArchiveSha = $Matches[1].ToLowerInvariant()
$expectedArchiveSha = $ExpectedArchiveSha256.ToLowerInvariant()
if ($recordedArchiveSha -ne $expectedArchiveSha) {
    throw "qpdf archive provenance mismatch: expected $expectedArchiveSha, got $recordedArchiveSha."
}

$checksumText = Get-Content -LiteralPath $checksums -Raw
if ($checksumText -notmatch '(?im)^([0-9a-f]{64})\s+bin/qpdf\.exe\s*$') {
    throw 'qpdf SHA256SUMS.txt does not contain bin/qpdf.exe.'
}
$recordedExeSha = $Matches[1].ToLowerInvariant()
$actualExeSha = (Get-FileHash -LiteralPath $qpdfExe -Algorithm SHA256).Hash.ToLowerInvariant()
if ($recordedExeSha -ne $actualExeSha) {
    throw "Packaged qpdf.exe SHA-256 mismatch: recorded $recordedExeSha, actual $actualExeSha."
}

$versionOutput = (& $qpdfExe --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Packaged qpdf --version failed with exit code $LASTEXITCODE: $versionOutput"
}
if ($versionOutput -notmatch ('(?i)qpdf\s+version\s+' + [Regex]::Escape($Version) + '(?:\D|$)')) {
    throw "Packaged qpdf did not report expected version $Version. Output: $versionOutput"
}
Write-Host "Packaged qpdf direct version check: $versionOutput"

$originalPath = $env:PATH
try {
    $system32 = Join-Path $env:SystemRoot 'System32'
    $env:PATH = [string]::Join([System.IO.Path]::PathSeparator, @($qpdfBin, $system32, $env:SystemRoot))

    $whereOutput = @(& where.exe qpdf 2>$null)
    if ($LASTEXITCODE -ne 0 -or $whereOutput.Count -eq 0) {
        throw 'qpdf could not be resolved from the isolated package-first PATH.'
    }

    $resolvedQpdf = [System.IO.Path]::GetFullPath([string]$whereOutput[0]).TrimEnd('\')
    $expectedQpdf = [System.IO.Path]::GetFullPath($qpdfExe).TrimEnd('\')
    if (-not $resolvedQpdf.Equals($expectedQpdf, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Isolated PATH resolved qpdf outside the portable tree: $resolvedQpdf"
    }

    $isolatedOutput = (& qpdf --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $isolatedOutput -notmatch [Regex]::Escape($Version)) {
        throw "Package-first PATH qpdf validation failed: $isolatedOutput"
    }
    Write-Host "Isolated PATH qpdf resolution: $resolvedQpdf"
}
finally {
    $env:PATH = $originalPath
}

# Always create the functional fixture ourselves. The former repository fixture
# test_globalsign.pdf was discovered in Run #64 to contain a GlobalSign HTML 404
# page rather than PDF bytes, so an external/misnamed fixture must not be able to
# create a false qpdf failure again.
$validationDir = Join-Path $portable 'data\validation'
New-Item -ItemType Directory -Force -Path $validationDir | Out-Null
$generatedPdf = Join-Path $validationDir 'qpdf-smoke.pdf'
$ascii = [System.Text.Encoding]::ASCII
$stream = [System.IO.MemoryStream]::new()
try {
    function Write-AsciiPdf {
        param([Parameter(Mandatory = $true)][string]$Text)
        $bytes = $ascii.GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
    }

    $offsets = [System.Collections.Generic.List[long]]::new()
    Write-AsciiPdf "%PDF-1.4`n"

    $offsets.Add($stream.Position)
    Write-AsciiPdf "1 0 obj`n<< /Type /Catalog /Pages 2 0 R >>`nendobj`n"

    $offsets.Add($stream.Position)
    Write-AsciiPdf "2 0 obj`n<< /Type /Pages /Kids [3 0 R] /Count 1 >>`nendobj`n"

    $offsets.Add($stream.Position)
    Write-AsciiPdf "3 0 obj`n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> >>`nendobj`n"

    $xrefOffset = $stream.Position
    Write-AsciiPdf "xref`n0 4`n"
    Write-AsciiPdf "0000000000 65535 f `n"
    foreach ($offset in $offsets) {
        Write-AsciiPdf (("{0:D10} 00000 n `n" -f $offset))
    }
    Write-AsciiPdf "trailer`n<< /Size 4 /Root 1 0 R >>`nstartxref`n$xrefOffset`n%%EOF`n"

    [System.IO.File]::WriteAllBytes($generatedPdf, $stream.ToArray())
}
finally {
    $stream.Dispose()
}

try {
    $signatureBytes = [System.IO.File]::ReadAllBytes($generatedPdf)
    if ($signatureBytes.Length -lt 5 -or $ascii.GetString($signatureBytes, 0, 5) -ne '%PDF-') {
        throw "Generated qpdf smoke fixture does not start with a PDF signature: $generatedPdf"
    }

    $checkOutput = (& $qpdfExe --check $generatedPdf 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged qpdf --check failed against generated PDF '$generatedPdf': $checkOutput"
    }

    $pageOutput = (& $qpdfExe --show-npages $generatedPdf 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged qpdf failed to inspect generated PDF '$generatedPdf': $pageOutput"
    }
    if ($pageOutput -ne '1') {
        throw "Packaged qpdf returned an unexpected page count for generated PDF '$generatedPdf': $pageOutput"
    }
    Write-Host 'Packaged qpdf generated-PDF check passed: structurally valid, 1 page.'

    if ($SamplePdf) {
        $legacySample = Resolve-Path -LiteralPath $SamplePdf -ErrorAction SilentlyContinue
        if ($legacySample) {
            $sampleBytes = [System.IO.File]::ReadAllBytes($legacySample.Path)
            $isPdf = $sampleBytes.Length -ge 5 -and $ascii.GetString($sampleBytes, 0, 5) -eq '%PDF-'
            if ($isPdf) {
                $legacyOutput = (& $qpdfExe --show-npages $legacySample.Path 2>&1 | Out-String).Trim()
                if ($LASTEXITCODE -ne 0) {
                    throw "Packaged qpdf failed to inspect optional repository PDF '$($legacySample.Path)': $legacyOutput"
                }
                Write-Host "Optional repository PDF also passed qpdf inspection: $legacyOutput page(s)."
            }
            else {
                Write-Warning "Ignoring optional SamplePdf because it is not a PDF by signature: $($legacySample.Path). The generated PDF gate above remains mandatory."
            }
        }
    }
}
finally {
    Remove-Item -LiteralPath $generatedPdf -Force -ErrorAction SilentlyContinue
    if ((Test-Path -LiteralPath $validationDir -PathType Container) -and -not (Get-ChildItem -LiteralPath $validationDir -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $validationDir -Force -ErrorAction SilentlyContinue
    }
}

if ($RequireBackendProbe) {
    if (-not $BackendLogRoot) {
        throw '-RequireBackendProbe requires -BackendLogRoot.'
    }
    $logRoot = (Resolve-Path -LiteralPath $BackendLogRoot).Path
    $logText = (
        Get-ChildItem -LiteralPath $logRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue |
            ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }
    ) -join "`n"

    if ([string]::IsNullOrWhiteSpace($logText)) {
        throw "No backend log text was available under $logRoot for qpdf dependency proof."
    }
    if ($logText -match '(?i)Missing dependency:\s*qpdf') {
        throw 'Stirling backend reported qpdf as a missing dependency.'
    }
    $expectedProbe = 'qpdf\s+' + [Regex]::Escape($Version) + '\s+meets minimum\s+12\.0\.0'
    if ($logText -notmatch $expectedProbe) {
        throw "Stirling backend logs did not prove qpdf $Version met the required 12.0.0 minimum."
    }
    Write-Host "Stirling backend dependency probe confirmed packaged qpdf $Version."
}

$archives = @(Get-ChildItem -LiteralPath $qpdfRoot -Recurse -Force -File -Filter '*.zip' -ErrorAction SilentlyContinue)
if ($archives.Count -gt 0) {
    $archives | Select-Object FullName, Length | Format-Table -AutoSize
    throw 'Downloaded qpdf archive is present in the final tool directory.'
}

Write-Host "PASS: qpdf $Version is package-local, hash-verified, runnable, functionally PDF-tested and independent of runner-installed qpdf."
