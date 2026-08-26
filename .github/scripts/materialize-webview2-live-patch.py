from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
expected_head = "e3dd3cc2e00566cdb92d398ff5986111f13026a9"


def run(*args):
    return subprocess.check_output(args, cwd=repo, text=True).strip()


actual_head = run("git", "rev-parse", "HEAD")
if actual_head != expected_head:
    raise SystemExit(
        f"Staging HEAD moved unexpectedly. Expected {expected_head}, got {actual_head}."
    )

validator = repo / ".github/scripts/validate-webview2-fixed-runtime.ps1"
text = validator.read_text(encoding="utf-8")
old_acl = '''  $expectedSids = @('S-1-15-2-1', 'S-1-15-2-2')
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
'''
new_acl = '''  $expectedSids = @('S-1-15-2-1', 'S-1-15-2-2')
  $acl = Get-Acl -LiteralPath $fixedRoot
  $sidRules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
  $requiredInheritance = [System.Security.AccessControl.InheritanceFlags]::ObjectInherit -bor [System.Security.AccessControl.InheritanceFlags]::ContainerInherit
  foreach ($sid in $expectedSids) {
    $matched = $false
    foreach ($rule in $sidRules) {
      $ruleSid = $rule.IdentityReference.Value
      $hasReadExecute = (($rule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq [System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
      $hasRequiredInheritance = (($rule.InheritanceFlags -band $requiredInheritance) -eq $requiredInheritance)
      if ($ruleSid -eq $sid -and $rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow -and $hasReadExecute -and $hasRequiredInheritance) {
        $matched = $true
        break
      }
    }
    if (-not $matched) {
      Write-Host 'Current Fixed Runtime ACL (SID-native rules):'
      $sidRules | Format-Table IdentityReference, FileSystemRights, AccessControlType, InheritanceFlags, IsInherited -AutoSize
      throw "Fixed WebView2 Runtime is missing an inheritable Allow ReadAndExecute ACE for $sid."
    }
  }
'''
if text.count(old_acl) != 1:
    raise SystemExit(f"Expected exactly one legacy ACL validation block, found {text.count(old_acl)}.")
validator.write_text(text.replace(old_acl, new_acl), encoding="utf-8", newline="\n")

readme = repo / "README.md"
readme_note = '''

### WebView2 live-launch evidence — staging Run `32969103123`

The persisted diagnostic artifact from staging Run `32969103123` proved that the packaged application itself is selecting the intended runtime correctly: `PDF_Tunner.exe` launched `runtime\\webview2\\fixed\\msedgewebview2.exe` with ProductVersion `151.0.4129.101`, its WebView2 command line used the package-local `data\\webview2\\EBWebView` profile, and the bundled Java process ran from `runtime\\jre\\bin\\java.exe`. The failure was therefore a validator false negative, not a runtime fallback or portability failure. `Get-Acl` showed explicit ReadAndExecute rules for `ALL APPLICATION PACKAGES` (`S-1-15-2-1`) and `ALL RESTRICTED APPLICATION PACKAGES` (`S-1-15-2-2`), but translating each returned `NTAccount` back to `SecurityIdentifier` did not reliably resolve those AppContainer identities. Live ACL validation now asks the .NET ACL object for access rules directly as `SecurityIdentifier` objects and still requires Allow + ReadAndExecute + ObjectInherit + ContainerInherit for both SIDs.
'''
readme.write_text(readme.read_text(encoding="utf-8") + readme_note, encoding="utf-8", newline="\n")

agents = repo / "AGENTS.md"
agents_note = '''

### Fixed WebView2 ACL validator correction after Run `32969103123`

- The Run `32969103123` diagnostic artifact is accepted evidence that the live package selected `runtime\\webview2\\fixed\\msedgewebview2.exe` version `151.0.4129.101`, used `data\\webview2\\EBWebView`, and launched Java from the package-local JRE. Treat that run's step-15 failure as an ACL-validator false negative, not as WebView2 Evergreen/system fallback.
- For AppContainer ACL validation, obtain rules directly with `GetAccessRules(..., [SecurityIdentifier])`; do not translate each `NTAccount` returned by `Get-Acl.Access` back to a SID, because the AppContainer identities can fail that reverse translation even when the ACE exists.
- Continue requiring explicit semantic evidence for both `S-1-15-2-1` and `S-1-15-2-2`: Allow, ReadAndExecute, ObjectInherit and ContainerInherit. Do not weaken the Windows 10 Fixed Runtime ACL requirement merely to make staging green.
'''
agents.write_text(agents.read_text(encoding="utf-8") + agents_note, encoding="utf-8", newline="\n")

subprocess.check_call(["git", "diff", "--check"], cwd=repo)
changed = sorted(
    line[3:]
    for line in subprocess.check_output(
        ["git", "status", "--porcelain"], cwd=repo, text=True
    ).splitlines()
)
expected = sorted(
    [
        ".github/scripts/validate-webview2-fixed-runtime.ps1",
        "AGENTS.md",
        "README.md",
    ]
)
if changed != expected:
    raise SystemExit(f"Unexpected staging diff: {changed}")

subprocess.check_call(["git", "config", "user.name", "WillsitoGG"], cwd=repo)
subprocess.check_call(
    ["git", "config", "user.email", "179575519+WillsitoGG@users.noreply.github.com"],
    cwd=repo,
)
subprocess.check_call(["git", "add", "--", *expected], cwd=repo)
subprocess.check_call(
    ["git", "commit", "-m", "fix(portable): validate WebView2 AppContainer ACLs by SID"],
    cwd=repo,
)
subprocess.check_call(
    ["git", "push", "origin", "HEAD:pdf-tunner/webview2-fixed-v151-final-stage"],
    cwd=repo,
)
print(run("git", "rev-parse", "HEAD"))
