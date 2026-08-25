param(
  [Parameter(Mandatory = $true)]
  [string]$PortableRoot,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [ValidateSet('x64', 'x86', 'arm64')]
  [string]$Architecture = 'x64',

  [Parameter(Mandatory = $true)]
  [string]$DownloadUrl,

  [string]$ExpectedSha256 = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$portable = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $PortableRoot))
$webViewRoot = Join-Path $portable 'runtime\webview2'
$fixedRoot = Join-Path $webViewRoot 'fixed'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-webview2-{0}" -f [guid]::NewGuid().ToString('N'))
$cabName = "Microsoft.WebView2.FixedVersionRuntime.$Version.$Architecture.cab"
$cabPath = Join-Path $tempRoot $cabName
$expandedRoot = Join-Path $tempRoot 'expanded'
$allowedHosts = @(
  'msedge.sf.dl.delivery.mp.microsoft.com',
  'msedge.b.tlu.dl.delivery.mp.microsoft.com'
)

New-Item -ItemType Directory -Force -Path $tempRoot, $expandedRoot, $webViewRoot | Out-Null
Remove-Item -LiteralPath $fixedRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $fixedRoot | Out-Null

try {
  $downloadUrl = $DownloadUrl.Trim()
  if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
    throw 'Pinned WebView2 Fixed Runtime download URL is empty.'
  }

  $uri = [Uri]$downloadUrl
  $host = $uri.Host.ToLowerInvariant()
  if ($uri.Scheme -ne 'https' -or $allowedHosts -notcontains $host) {
    throw "Refusing WebView2 download URL outside the approved Microsoft Edge CDN hosts: $downloadUrl"
  }
  if ($uri.AbsoluteUri -match '(?i)(PA30|PA19)') {
    throw "Resolved WebView2 payload appears to be a delta package rather than a complete Fixed Runtime: $downloadUrl"
  }
  $resolvedName = [Uri]::UnescapeDataString([System.IO.Path]::GetFileName($uri.AbsolutePath))
  if ($resolvedName -ne $cabName) {
    throw "Pinned WebView2 payload filename '$resolvedName' does not match expected '$cabName'."
  }

  Write-Host "Using pinned official Microsoft WebView2 Fixed Runtime URL for $Version / $Architecture from $host."
  Invoke-WebRequest -Uri $downloadUrl -OutFile $cabPath -UseBasicParsing -MaximumRedirection 10 -TimeoutSec 900

  $cabHash = (Get-FileHash -LiteralPath $cabPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Host "Official WebView2 Fixed Runtime CAB SHA-256: $cabHash"

  if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
    $expected = $ExpectedSha256.Trim().ToLowerInvariant()
    if ($expected -notmatch '^[0-9a-f]{64}$') {
      throw "Expected WebView2 CAB SHA-256 is not a valid 64-hex digest: $ExpectedSha256"
    }
    if ($cabHash -ne $expected) {
      throw "WebView2 Fixed Runtime CAB SHA-256 mismatch. Expected $expected, got $cabHash."
    }
  }
  else {
    throw 'ExpectedSha256 must be pinned for a Fixed WebView2 staging build.'
  }

  & expand.exe $cabPath -F:* $expandedRoot | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "expand.exe failed with exit code $LASTEXITCODE."
  }

  $runtimeExe = Get-ChildItem -LiteralPath $expandedRoot -Recurse -File -Filter 'msedgewebview2.exe' | Select-Object -First 1
  if (-not $runtimeExe) {
    throw 'Expanded Microsoft Fixed WebView2 Runtime does not contain msedgewebview2.exe.'
  }

  $sourceRoot = $runtimeExe.Directory.FullName
  Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $fixedRoot -Recurse -Force

  $packagedExe = Join-Path $fixedRoot 'msedgewebview2.exe'
  if (-not (Test-Path -LiteralPath $packagedExe -PathType Leaf)) {
    throw "Normalized WebView2 runtime is missing $packagedExe."
  }

  $productVersion = (Get-Item -LiteralPath $packagedExe).VersionInfo.ProductVersion
  if ([string]::IsNullOrWhiteSpace($productVersion) -or $productVersion -notlike "$Version*") {
    throw "Packaged msedgewebview2.exe reports unexpected ProductVersion '$productVersion'; expected $Version."
  }

  Set-Content -LiteralPath (Join-Path $webViewRoot 'version.txt') -Encoding ascii -Value @(
    "Version=$Version",
    "Architecture=$Architecture"
  )
  Set-Content -LiteralPath (Join-Path $webViewRoot 'SHA256SUMS.txt') -Encoding ascii -Value "$cabHash  $cabName"
  Set-Content -LiteralPath (Join-Path $webViewRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
    'Microsoft Edge WebView2 Fixed Runtime',
    "Version=$Version",
    "Architecture=$Architecture",
    "CAB_SHA256=$cabHash",
    "Source_URL=$downloadUrl",
    "CDN_Host=$host",
    'Verification=URL host + exact CAB filename + pinned SHA-256 + packaged msedgewebview2.exe ProductVersion'
  )

  $files = @(Get-ChildItem -LiteralPath $fixedRoot -Recurse -Force -File)
  $bytes = ($files | Measure-Object -Property Length -Sum).Sum
  Write-Host "Packaged Microsoft WebView2 Fixed Runtime: $productVersion"
  Write-Host "Normalized runtime root: $fixedRoot"
  Write-Host "Runtime tree: $($files.Count) files / $bytes bytes"
}
finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
