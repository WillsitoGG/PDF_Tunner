param(
  [Parameter(Mandatory = $true)]
  [string]$PortableRoot,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [switch]$RequireLiveProcess
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$fixedRoot = Join-Path $portable 'runtime\webview2\fixed'
$runtimeExe = Join-Path $fixedRoot 'msedgewebview2.exe'
$provenance = Join-Path $portable 'runtime\webview2\PROVENANCE.txt'

if (-not (Test-Path -LiteralPath $runtimeExe -PathType Leaf)) {
  throw "Bundled Fixed WebView2 executable is missing: $runtimeExe"
}

$productVersion = (Get-Item -LiteralPath $runtimeExe).VersionInfo.ProductVersion
if ([string]::IsNullOrWhiteSpace($productVersion) -or $productVersion -notlike "$Version*") {
  throw "Bundled Fixed WebView2 ProductVersion '$productVersion' does not match expected $Version."
}

if (-not (Test-Path -LiteralPath $provenance -PathType Leaf)) {
  throw "Bundled Fixed WebView2 provenance file is missing: $provenance"
}

$provenanceText = Get-Content -LiteralPath $provenance -Raw
if ($provenanceText -notmatch "(?m)^Version=$([Regex]::Escape($Version))\s*$") {
  throw "WebView2 provenance does not record expected version $Version."
}
if ($provenanceText -notmatch '(?m)^Architecture=x64\s*$') {
  throw 'WebView2 provenance does not record x64 architecture.'
}
if ($provenanceText -notmatch '(?m)^CAB_SHA256=([0-9a-fA-F]{64})\s*$') {
  throw 'WebView2 provenance does not contain a valid 64-hex CAB SHA-256.'
}
if ($provenanceText -notmatch '(?m)^Source=https://developer\.microsoft\.com/en-us/microsoft-edge/webview2\s*$') {
  throw 'WebView2 provenance does not identify the official Microsoft selector as its source.'
}

if ($RequireLiveProcess) {
  # ACLs are deliberately checked only after PDF_Tunner has started. ZIP
  # extraction does not reliably preserve NTFS ACLs, so the application itself
  # must recreate Microsoft's Windows 10 AppContainer RX grants at runtime.
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

  $normalizedRoot = [System.IO.Path]::GetFullPath($fixedRoot).TrimEnd('\') + '\'
  $deadline = (Get-Date).AddSeconds(30)
  $localProcesses = @()

  while ((Get-Date) -lt $deadline -and $localProcesses.Count -eq 0) {
    $edgeProcesses = @(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" -ErrorAction SilentlyContinue)
    $localProcesses = @($edgeProcesses | Where-Object {
      $_.ExecutablePath -and [System.IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)
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

  Write-Host 'Package-local Fixed WebView2 processes:'
  $localProcesses |
    Select-Object ProcessId, ParentProcessId, ExecutablePath |
    Format-Table -AutoSize
}

Write-Host "PASS: Microsoft Fixed WebView2 $productVersion is package-local and provenance-backed; live-process mode additionally proved runtime ACLs and actual process selection."
