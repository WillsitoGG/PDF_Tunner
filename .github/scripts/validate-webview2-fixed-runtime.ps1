param(
  [Parameter(Mandatory = $true)]
  [string]$PortableRoot,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [ValidateSet('x64', 'x86', 'arm64')]
  [string]$Architecture = 'x64',

  [string]$ExpectedCabSha256 = '',

  [switch]$RequireLiveProcess
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
if ($portable.StartsWith('\\')) {
  throw "Microsoft Fixed WebView2 Runtime cannot be validated from a UNC path: $portable"
}

$webViewRoot = Join-Path $portable 'runtime\webview2'
$fixedRoot = Join-Path $webViewRoot 'fixed'
$runtimeExe = Join-Path $fixedRoot 'msedgewebview2.exe'
$provenance = Join-Path $webViewRoot 'PROVENANCE.txt'
$versionFile = Join-Path $webViewRoot 'version.txt'
$shaFile = Join-Path $webViewRoot 'SHA256SUMS.txt'
$profileRoot = Join-Path $portable 'data\webview2'

foreach ($required in @($runtimeExe, $provenance, $versionFile, $shaFile)) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
    throw "Bundled Fixed WebView2 required file is missing: $required"
  }
}

$productVersion = (Get-Item -LiteralPath $runtimeExe).VersionInfo.ProductVersion
if ([string]::IsNullOrWhiteSpace($productVersion) -or $productVersion -notlike "$Version*") {
  throw "Bundled Fixed WebView2 ProductVersion '$productVersion' does not match expected $Version."
}

$provenanceText = Get-Content -LiteralPath $provenance -Raw
if ($provenanceText -notmatch "(?m)^Version=$([Regex]::Escape($Version))\s*$") {
  throw "WebView2 provenance does not record expected version $Version."
}
if ($provenanceText -notmatch "(?m)^Architecture=$([Regex]::Escape($Architecture))\s*$") {
  throw "WebView2 provenance does not record expected architecture $Architecture."
}
if ($provenanceText -notmatch '(?m)^CAB_SHA256=([0-9a-fA-F]{64})\s*$') {
  throw 'WebView2 provenance does not contain a valid 64-hex CAB SHA-256.'
}
$provenanceHash = $Matches[1].ToLowerInvariant()
if ($provenanceText -notmatch '(?m)^CDN_Host=(msedge\.sf\.dl\.delivery\.mp\.microsoft\.com|msedge\.b\.tlu\.dl\.delivery\.mp\.microsoft\.com)\s*$') {
  throw 'WebView2 provenance does not identify an approved Microsoft Edge delivery CDN host.'
}

$versionText = Get-Content -LiteralPath $versionFile -Raw
if ($versionText -notmatch "(?m)^Version=$([Regex]::Escape($Version))\s*$" -or $versionText -notmatch "(?m)^Architecture=$([Regex]::Escape($Architecture))\s*$") {
  throw 'WebView2 version.txt metadata does not match the requested fixed runtime.'
}

$shaText = (Get-Content -LiteralPath $shaFile -Raw).Trim()
$expectedCabName = "Microsoft.WebView2.FixedVersionRuntime.$Version.$Architecture.cab"
if ($shaText -notmatch "^([0-9a-fA-F]{64})\s{2}$([Regex]::Escape($expectedCabName))$") {
  throw 'WebView2 SHA256SUMS.txt is malformed or refers to an unexpected CAB name.'
}
$sumHash = $Matches[1].ToLowerInvariant()
if ($sumHash -ne $provenanceHash) {
  throw "WebView2 provenance/SHA256SUMS digest disagreement: $provenanceHash vs $sumHash"
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedCabSha256)) {
  $expected = $ExpectedCabSha256.Trim().ToLowerInvariant()
  if ($expected -notmatch '^[0-9a-f]{64}$') {
    throw "Expected WebView2 CAB SHA-256 is not a valid 64-hex digest: $ExpectedCabSha256"
  }
  if ($provenanceHash -ne $expected) {
    throw "Bundled WebView2 provenance digest $provenanceHash does not match pinned digest $expected."
  }
}

$runtimeFiles = @(Get-ChildItem -LiteralPath $fixedRoot -Recurse -Force -File)
$runtimeBytes = ($runtimeFiles | Measure-Object -Property Length -Sum).Sum
if ($runtimeFiles.Count -lt 20 -or $runtimeBytes -lt 50000000) {
  throw "Bundled Fixed WebView2 tree looks incomplete: $($runtimeFiles.Count) files / $runtimeBytes bytes."
}
$forbiddenPayloads = @(Get-ChildItem -LiteralPath $webViewRoot -Recurse -Force -File | Where-Object { $_.Extension -match '^(?i)\.(cab|msi|exe)$' -and $_.FullName -ne $runtimeExe })
$forbiddenPayloads = @($forbiddenPayloads | Where-Object { $_.FullName -notlike "$fixedRoot*" })
if ($forbiddenPayloads.Count -gt 0) {
  $forbiddenPayloads | Select-Object FullName, Length | Format-Table -AutoSize
  throw 'Installer/archive payloads were left next to the normalized Fixed WebView2 Runtime.'
}

if ($RequireLiveProcess) {
  $expectedSids = @('S-1-15-2-1', 'S-1-15-2-2')
  $acl = Get-Acl -LiteralPath $fixedRoot
  foreach ($sid in $expectedSids) {
    $matched = $false
    foreach ($rule in $acl.Access) {
      try {
        $ruleSid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
      }
      catch {
        continue
      }
      $hasReadExecute = (($rule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq [System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
      if ($ruleSid -eq $sid -and $rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and $hasReadExecute) {
        $matched = $true
        break
      }
    }
    if (-not $matched) {
      Write-Host 'Current Fixed Runtime ACL:'
      $acl.Access | Format-Table IdentityReference, FileSystemRights, AccessControlType, IsInherited -AutoSize
      throw "Fixed WebView2 Runtime is missing an Allow ReadAndExecute ACE for $sid."
    }
  }

  $normalizedRuntime = [System.IO.Path]::GetFullPath($fixedRoot).TrimEnd('\') + '\'
  $normalizedProfile = [System.IO.Path]::GetFullPath($profileRoot).TrimEnd('\')
  $deadline = (Get-Date).AddSeconds(45)
  $localProcesses = @()
  while ((Get-Date) -lt $deadline -and $localProcesses.Count -eq 0) {
    $edgeProcesses = @(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" -ErrorAction SilentlyContinue)
    $localProcesses = @($edgeProcesses | Where-Object {
      $_.ExecutablePath -and [System.IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($normalizedRuntime, [System.StringComparison]::OrdinalIgnoreCase)
    })
    if ($localProcesses.Count -eq 0) {
      Start-Sleep -Milliseconds 500
    }
  }

  if ($localProcesses.Count -eq 0) {
    Write-Host 'Observed msedgewebview2.exe processes:'
    Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" -ErrorAction SilentlyContinue |
      Select-Object ProcessId, ParentProcessId, ExecutablePath, CommandLine |
      Format-List
    throw "No live WebView2 process is executing from package-local Fixed Runtime root: $fixedRoot"
  }

  $profileEvidence = @($localProcesses | Where-Object {
    $_.CommandLine -and $_.CommandLine.IndexOf('--user-data-dir', [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
      $_.CommandLine.IndexOf($normalizedProfile, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
  })
  if ($profileEvidence.Count -eq 0) {
    $localProcesses | Select-Object ProcessId, ExecutablePath, CommandLine | Format-List
    throw "Package-local WebView2 processes did not advertise the expected package-local user-data directory: $normalizedProfile"
  }

  $debugProcesses = @($localProcesses | Where-Object { $_.CommandLine -and $_.CommandLine -match '(?i)--remote-debugging-port' })
  if ($debugProcesses.Count -gt 0) {
    $debugProcesses | Select-Object ProcessId, CommandLine | Format-List
    throw 'Release WebView2 process unexpectedly exposes a remote debugging port.'
  }

  if (-not (Test-Path -LiteralPath $profileRoot -PathType Container)) {
    throw "Package-local WebView2 profile directory was not created: $profileRoot"
  }
  $profileFiles = @(Get-ChildItem -LiteralPath $profileRoot -Recurse -Force -File -ErrorAction SilentlyContinue)
  if ($profileFiles.Count -eq 0) {
    throw "Package-local WebView2 profile directory remained empty: $profileRoot"
  }

  Write-Host 'Package-local Fixed WebView2 processes:'
  $localProcesses | Select-Object ProcessId, ParentProcessId, ExecutablePath, CommandLine | Format-Table -Wrap -AutoSize
  Write-Host "Package-local WebView2 profile: $($profileFiles.Count) files under $profileRoot"
}

Write-Host "PASS: Microsoft Fixed WebView2 $productVersion is package-local, provenance-backed, complete, and free of installer payloads; live mode additionally proves Windows 10 AppContainer ACLs, actual fixed-runtime process selection, and package-local browser profile state."
