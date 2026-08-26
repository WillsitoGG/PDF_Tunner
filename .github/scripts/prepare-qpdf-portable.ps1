param(
  [Parameter(Mandatory = $true)]
  [string]$PortableRoot,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$DownloadUrl,

  [Parameter(Mandatory = $true)]
  [string]$ExpectedSha256
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$portable = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $PortableRoot))
$toolRoot = Join-Path $portable 'tools\qpdf'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-qpdf-{0}" -f [guid]::NewGuid().ToString('N'))
$zipName = "qpdf-$Version-msvc64.zip"
$zipPath = Join-Path $tempRoot $zipName
$expandedRoot = Join-Path $tempRoot 'expanded'
$expectedUrl = "https://github.com/qpdf/qpdf/releases/download/v$Version/$zipName"

New-Item -ItemType Directory -Force -Path $tempRoot, $expandedRoot | Out-Null
Remove-Item -LiteralPath $toolRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null

try {
  $url = $DownloadUrl.Trim()
  if ($url -ne $expectedUrl) {
    throw "Refusing qpdf URL other than the pinned official release asset: $url"
  }

  $expected = $ExpectedSha256.Trim().ToLowerInvariant()
  if ($expected -notmatch '^[0-9a-f]{64}$') {
    throw "Expected qpdf SHA-256 is not a valid 64-hex digest: $ExpectedSha256"
  }

  Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -MaximumRedirection 10 -TimeoutSec 600
  $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($hash -ne $expected) {
    throw "qpdf ZIP SHA-256 mismatch. Expected $expected, got $hash."
  }

  Expand-Archive -LiteralPath $zipPath -DestinationPath $expandedRoot -Force
  $executables = @(Get-ChildItem -LiteralPath $expandedRoot -Recurse -File -Filter 'qpdf.exe')
  if ($executables.Count -ne 1) {
    throw "Expected exactly one qpdf.exe in official archive, found $($executables.Count)."
  }

  $sourceRoot = $executables[0].Directory.Parent.FullName
  Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $toolRoot -Recurse -Force

  $packagedExe = Join-Path $toolRoot 'bin\qpdf.exe'
  if (-not (Test-Path -LiteralPath $packagedExe -PathType Leaf)) {
    throw "Normalized qpdf package is missing $packagedExe."
  }

  $versionOutput = (& $packagedExe --version 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "(?m)^qpdf version $([Regex]::Escape($Version))$") {
    throw "Packaged qpdf version check failed: $versionOutput"
  }

  Set-Content -LiteralPath (Join-Path $toolRoot 'version.txt') -Encoding ascii -Value "Version=$Version"
  Set-Content -LiteralPath (Join-Path $toolRoot 'SHA256SUMS.txt') -Encoding ascii -Value "$hash  $zipName"
  Set-Content -LiteralPath (Join-Path $toolRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
    'qpdf official Windows MSVC64 binary distribution',
    "Version=$Version",
    'Architecture=x64',
    "ZIP_SHA256=$hash",
    "Source_URL=$url",
    'Verification=exact official GitHub release URL + pinned SHA-256 + qpdf.exe --version'
  )

  $files = @(Get-ChildItem -LiteralPath $toolRoot -Recurse -Force -File)
  $bytes = ($files | Measure-Object -Property Length -Sum).Sum
  Write-Host "Packaged qpdf $Version: $($files.Count) files / $bytes bytes"
}
finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
