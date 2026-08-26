param(
  [Parameter(Mandatory = $true)]
  [string]$PortableRoot,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$ExpectedZipSha256,

  [switch]$RequirePathDiscovery
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolRoot = Join-Path $portable 'tools\qpdf'
$bin = Join-Path $toolRoot 'bin'
$qpdf = Join-Path $bin 'qpdf.exe'
$provenance = Join-Path $toolRoot 'PROVENANCE.txt'
$versionFile = Join-Path $toolRoot 'version.txt'
$shaFile = Join-Path $toolRoot 'SHA256SUMS.txt'

foreach ($required in @($qpdf, $provenance, $versionFile, $shaFile)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Bundled qpdf required file is missing: $required"
  }
}

$versionOutput = (& $qpdf --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "(?m)^qpdf version $([Regex]::Escape($Version))$") {
  throw "Bundled qpdf version check failed: $versionOutput"
}

$provenanceText = Get-Content -LiteralPath $provenance -Raw
if ($provenanceText -notmatch "(?m)^Version=$([Regex]::Escape($Version))\s*$") {
  throw "qpdf provenance does not record expected version $Version."
}
if ($provenanceText -notmatch '(?m)^Architecture=x64\s*$') {
  throw 'qpdf provenance does not record x64 architecture.'
}
if ($provenanceText -notmatch '(?m)^ZIP_SHA256=([0-9a-fA-F]{64})\s*$') {
  throw 'qpdf provenance does not contain a valid ZIP SHA-256.'
}
$provenanceHash = $Matches[1].ToLowerInvariant()
$expected = $ExpectedZipSha256.Trim().ToLowerInvariant()
if ($expected -notmatch '^[0-9a-f]{64}$' -or $provenanceHash -ne $expected) {
  throw "qpdf provenance hash mismatch. Expected $expected, got $provenanceHash."
}

$zipName = "qpdf-$Version-msvc64.zip"
$shaText = (Get-Content -LiteralPath $shaFile -Raw).Trim()
if ($shaText -ne "$expected  $zipName") {
  throw 'qpdf SHA256SUMS.txt does not match the pinned ZIP digest/name.'
}

$versionText = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($versionText -ne "Version=$Version") {
  throw "qpdf version.txt mismatch: $versionText"
}

$archives = @(Get-ChildItem -LiteralPath $toolRoot -Recurse -Force -File | Where-Object { $_.Extension -match '^(?i)\.(zip|exe)$' -and $_.FullName -ne $qpdf })
$outsideBinExe = @($archives | Where-Object { $_.Extension -ieq '.exe' -and $_.DirectoryName -ne $bin })
$zips = @($archives | Where-Object { $_.Extension -ieq '.zip' })
if ($zips.Count -gt 0) {
  throw 'Downloaded qpdf ZIP leaked into the normalized portable tool tree.'
}
if ($outsideBinExe.Count -gt 0) {
  $outsideBinExe | Select-Object FullName, Length | Format-Table -AutoSize
  throw 'Unexpected executable exists outside qpdf bin directory.'
}

if ($RequirePathDiscovery) {
  $originalPath = $env:PATH
  try {
    $env:PATH = "$bin;$originalPath"
    $resolved = (& where.exe qpdf 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "where qpdf failed: $resolved" }
    $first = ($resolved -split "`r?`n")[0].Trim()
    if (-not $first.Equals($qpdf, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "PATH resolved qpdf outside package-local tool: $first"
    }
    $pathVersion = (& qpdf --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $pathVersion -notmatch "(?m)^qpdf version $([Regex]::Escape($Version))$") {
      throw "PATH qpdf version check failed: $pathVersion"
    }
  }
  finally {
    $env:PATH = $originalPath
  }
}

$files = @(Get-ChildItem -LiteralPath $toolRoot -Recurse -Force -File)
$bytes = ($files | Measure-Object -Property Length -Sum).Sum
Write-Host "PASS: qpdf $Version is package-local, provenance-backed, PATH-discoverable when requested, and normalized without its download archive. Tree: $($files.Count) files / $bytes bytes"
