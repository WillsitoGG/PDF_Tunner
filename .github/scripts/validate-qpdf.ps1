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

if ($SamplePdf) {
    $samplePath = (Resolve-Path -LiteralPath $SamplePdf).Path
    $pageOutput = (& $qpdfExe --show-npages $samplePath 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged qpdf failed to inspect sample PDF '$samplePath': $pageOutput"
    }
    $pageCount = 0
    if (-not [int]::TryParse($pageOutput, [ref]$pageCount) -or $pageCount -lt 1) {
        throw "Packaged qpdf returned an invalid page count for sample PDF '$samplePath': $pageOutput"
    }
    Write-Host "Packaged qpdf sample-PDF check passed: $pageCount page(s)."
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

Write-Host "PASS: qpdf $Version is package-local, hash-verified, runnable and independent of runner-installed qpdf."
