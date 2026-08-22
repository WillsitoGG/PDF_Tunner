param(
  [Parameter(Mandatory = $true)]
  [string]$PortableRoot,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [ValidateSet('x64', 'x86', 'arm64')]
  [string]$Architecture = 'x64',

  [string]$ExpectedSha256 = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$portable = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $PortableRoot))
$webViewRoot = Join-Path $portable 'runtime/webview2'
$fixedRoot = Join-Path $webViewRoot 'fixed'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-webview2-{0}" -f [guid]::NewGuid().ToString('N'))
$cabPath = Join-Path $tempRoot ("Microsoft.WebView2.FixedVersionRuntime.{0}.{1}.cab" -f $Version, $Architecture)
$expandedRoot = Join-Path $tempRoot 'expanded'

New-Item -ItemType Directory -Force -Path $tempRoot, $expandedRoot | Out-Null
Remove-Item -LiteralPath $fixedRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $fixedRoot | Out-Null

try {
  Push-Location (Join-Path $repoRoot 'frontend')
  try {
    $downloadUrl = (& node './scripts/pdf-tunner-resolve-webview2-fixed.mjs' $Version $Architecture).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($downloadUrl)) {
      throw 'Official WebView2 Fixed Runtime download URL could not be resolved.'
    }
  }
  finally {
    Pop-Location
  }

  $uri = [Uri]$downloadUrl
  if ($uri.Scheme -ne 'https' -or -not $uri.Host.ToLowerInvariant().EndsWith('.microsoft.com')) {
    throw "Refusing non-Microsoft WebView2 download URL: $downloadUrl"
  }

  Write-Host "Resolved official Microsoft WebView2 Fixed Runtime URL for $Version / $Architecture."
  Invoke-WebRequest -Uri $downloadUrl -OutFile $cabPath -UseBasicParsing

  $cabHash = (Get-FileHash -LiteralPath $cabPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Host "Official WebView2 Fixed Runtime CAB SHA-256: $cabHash"

  if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
    $expected = $ExpectedSha256.Trim().ToLowerInvariant()
    if ($cabHash -ne $expected) {
      throw "WebView2 Fixed Runtime CAB SHA-256 mismatch. Expected $expected, got $cabHash."
    }
  }
  else {
    Write-Warning 'ExpectedSha256 is not pinned yet. This staging run must record the official CAB hash before integration into the primary branch.'
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

  Set-Content -LiteralPath (Join-Path $webViewRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
    'Microsoft Edge WebView2 Fixed Runtime',
    "Version=$Version",
    "Architecture=$Architecture",
    "CAB_SHA256=$cabHash",
    'Source=https://developer.microsoft.com/en-us/microsoft-edge/webview2'
  )

  Write-Host "Packaged Microsoft WebView2 Fixed Runtime: $productVersion"
  Write-Host "Normalized runtime root: $fixedRoot"
}
finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
