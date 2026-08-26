from pathlib import Path
import shutil
import subprocess
import sys

primary = Path(sys.argv[1]).resolve()
staging = Path(sys.argv[2]).resolve()
helper_root = Path(__file__).resolve().parents[2]

EXPECTED_PRIMARY = "0e56e5b3a8113012f2f5ceb620fcfbeecbaa4eea"
EXPECTED_STAGING = "73f3d8c53eb59456d27bed7d7ba0243565988885"
ACCEPTED_RUN = "32977842546"


def git_head(repo: Path) -> str:
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()

if git_head(primary) != EXPECTED_PRIMARY:
    raise SystemExit(f"Primary HEAD moved unexpectedly: {git_head(primary)}")
if git_head(staging) != EXPECTED_STAGING:
    raise SystemExit(f"Staging HEAD moved unexpectedly: {git_head(staging)}")

# Promote only permanent implementation files from accepted staging.
for rel in [
    "frontend/editor/src-tauri/src/main.rs",
    "frontend/editor/src-tauri/Cargo.toml",
    ".github/scripts/prepare-webview2-fixed-runtime.ps1",
    ".github/scripts/validate-webview2-fixed-runtime.ps1",
]:
    src = staging / rel
    dst = primary / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)

workflow = primary / ".github/workflows/pdf-tunner-windows-portable.yml"
text = workflow.read_text(encoding="utf-8")

env_old = '''  PDF_TUNNER_UPSTREAM_COMMIT: "7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632"\n  CI: "true"\n'''
env_new = '''  PDF_TUNNER_UPSTREAM_COMMIT: "7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632"\n  PDF_TUNNER_WEBVIEW2_FIXED_VERSION: "151.0.4129.101"\n  PDF_TUNNER_WEBVIEW2_FIXED_ARCH: "x64"\n  PDF_TUNNER_WEBVIEW2_FIXED_URL: "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/d480b710-fe1e-4e4d-ae99-5b62e6391fd3/Microsoft.WebView2.FixedVersionRuntime.151.0.4129.101.x64.cab"\n  PDF_TUNNER_WEBVIEW2_FIXED_SHA256: "c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda"\n  CI: "true"\n'''
if text.count(env_old) != 1:
    raise SystemExit(f"Expected one primary env anchor, found {text.count(env_old)}")
text = text.replace(env_old, env_new)

java_marker = '''      - name: Validate bundled Java runtime\n'''
webview_steps = '''      - name: Stage official Microsoft Fixed WebView2 Runtime\n        shell: pwsh\n        run: |\n          & './.github/scripts/prepare-webview2-fixed-runtime.ps1' `\n            -PortableRoot './dist/PDF_Tunner' `\n            -Version $env:PDF_TUNNER_WEBVIEW2_FIXED_VERSION `\n            -Architecture $env:PDF_TUNNER_WEBVIEW2_FIXED_ARCH `\n            -DownloadUrl $env:PDF_TUNNER_WEBVIEW2_FIXED_URL `\n            -ExpectedSha256 $env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256\n\n      - name: Validate staged Fixed WebView2 metadata and tree\n        shell: pwsh\n        run: |\n          & './.github/scripts/validate-webview2-fixed-runtime.ps1' `\n            -PortableRoot './dist/PDF_Tunner' `\n            -Version $env:PDF_TUNNER_WEBVIEW2_FIXED_VERSION `\n            -Architecture $env:PDF_TUNNER_WEBVIEW2_FIXED_ARCH `\n            -ExpectedCabSha256 $env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256\n\n'''
if text.count(java_marker) != 1:
    raise SystemExit(f"Expected one Java marker, found {text.count(java_marker)}")
text = text.replace(java_marker, webview_steps + java_marker)

health_old = '''          Write-Host "Backend health check OK: $statusUri"\n\n          Write-Host 'Containment check: Stirling AppData'\n'''
health_new = '''          Write-Host "Backend health check OK: $statusUri"\n\n          & './.github/scripts/validate-webview2-fixed-runtime.ps1' `\n            -PortableRoot './dist/PDF_Tunner' `\n            -Version $env:PDF_TUNNER_WEBVIEW2_FIXED_VERSION `\n            -Architecture $env:PDF_TUNNER_WEBVIEW2_FIXED_ARCH `\n            -ExpectedCabSha256 $env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256 `\n            -RequireLiveProcess\n          if ($LASTEXITCODE -ne 0) { throw 'Fixed WebView2 live validation failed.' }\n\n          Write-Host 'Containment check: Stirling AppData'\n'''
if text.count(health_old) != 1:
    raise SystemExit(f"Expected one backend health anchor, found {text.count(health_old)}")
text = text.replace(health_old, health_new)

diag_marker = '''      - name: Collect portable startup diagnostics\n'''
acceptance_steps = '''      - name: Require pinned Fixed WebView2 CAB SHA\n        shell: pwsh\n        run: |\n          $provenance = Join-Path $PWD 'dist/PDF_Tunner/runtime/webview2/PROVENANCE.txt'\n          $text = Get-Content -LiteralPath $provenance -Raw\n          if ($text -notmatch '(?m)^CAB_SHA256=([0-9a-fA-F]{64})\\s*$') {\n            throw 'Fixed WebView2 provenance does not contain CAB_SHA256.'\n          }\n          $actual = $Matches[1].ToLowerInvariant()\n          $expected = $env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256.ToLowerInvariant()\n          if ($actual -ne $expected) {\n            throw "Fixed WebView2 CAB SHA mismatch at final acceptance: expected $expected, got $actual."\n          }\n\n      - name: Verify final portable layout contains no downloaded WebView2 CAB\n        shell: pwsh\n        run: |\n          $portable = Resolve-Path './dist/PDF_Tunner'\n          $cabs = @(Get-ChildItem -LiteralPath $portable -Recurse -Force -File -Filter '*.cab' -ErrorAction SilentlyContinue)\n          if ($cabs.Count -gt 0) {\n            $cabs | Select-Object FullName, Length | Format-Table -AutoSize\n            throw 'Downloaded WebView2 CAB leaked into the portable package.'\n          }\n          Write-Host 'PASS: portable package contains normalized Fixed WebView2 runtime only; no CAB archive remains.'\n\n'''
if text.count(diag_marker) != 1:
    raise SystemExit(f"Expected one diagnostics marker, found {text.count(diag_marker)}")
text = text.replace(diag_marker, acceptance_steps + diag_marker)

required_old = '''            'runtime/jre/bin/java.exe',\n            'data'\n'''
required_new = '''            'runtime/jre/bin/java.exe',\n            'runtime/webview2/fixed/msedgewebview2.exe',\n            'runtime/webview2/PROVENANCE.txt',\n            'runtime/webview2/SHA256SUMS.txt',\n            'runtime/webview2/version.txt',\n            'data'\n'''
if text.count(required_old) != 1:
    raise SystemExit(f"Expected one layout requirements anchor, found {text.count(required_old)}")
text = text.replace(required_old, required_new)

process_old = "Where-Object { $_.Name -match 'PDF_Tunner|java' -or ($_.CommandLine -and $_.CommandLine -match 'PDF_Tunner|Stirling') }"
process_new = "Where-Object { $_.Name -match 'PDF_Tunner|java|msedgewebview2' -or ($_.CommandLine -and $_.CommandLine -match 'PDF_Tunner|Stirling|webview2') }"
if text.count(process_old) != 1:
    raise SystemExit(f"Expected one diagnostics process filter, found {text.count(process_old)}")
text = text.replace(process_old, process_new)
workflow.write_text(text, encoding="utf-8", newline="\n")

readme = primary / "README.md"
readme_text = readme.read_text(encoding="utf-8")
readme_note = f'''\n\n### Fixed WebView2 accepted for the permanent Windows portable workflow\n\nStaging Run `{ACCEPTED_RUN}` is the acceptance gate for the package-local Microsoft Edge WebView2 Fixed Runtime. The full heavy job passed official Stirling desktop preparation, Tauri/Cargo tests, the production `PDF_Tunner.exe` build, portable assembly, exact Microsoft Fixed Runtime CAB download, pinned SHA-256 verification, normalization, static validation, Java 25 validation, real backend HTTP health, live process selection from `runtime\\webview2\\fixed`, package-local `data\\webview2` state, AppContainer ACL validation by SID, the two-launch/AppData/window-state containment proof, final SHA gate, and absence of any downloaded CAB in the portable tree. The permanent workflow now pins version `151.0.4129.101` x64 and CAB SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`; no Evergreen/system fallback is accepted.\n\nThe reproducible upstream snapshot remains commit `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`, whose own Gradle metadata reports `2.14.3`. This snapshot is intentionally recorded by commit SHA; it must not be conflated with the separate Git object currently referenced by the upstream `v2.14.3` tag.\n'''
if f"Staging Run `{ACCEPTED_RUN}` is the acceptance gate" in readme_text:
    raise SystemExit("README acceptance note already exists unexpectedly")
readme.write_text(readme_text + readme_note, encoding="utf-8", newline="\n")

agents = primary / "AGENTS.md"
agents_text = agents.read_text(encoding="utf-8")
agents_note = f'''\n\n### Permanent Fixed WebView2 acceptance\n\n- Staging Run `{ACCEPTED_RUN}` is the green acceptance evidence for Fixed WebView2 `151.0.4129.101` x64. Permanent Windows builds must retain the exact official Microsoft CDN CAB URL and SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`.\n- A passing build must prove static runtime integrity and live selection of package-local `runtime\\webview2\\fixed\\msedgewebview2.exe`, package-local `data\\webview2`, both AppContainer SID ACLs with Allow + ReadAndExecute + ObjectInherit + ContainerInherit, backend HTTP 200, two-launch/AppData/window-state containment, no orphan package-local child processes, and no CAB archive in the final portable root.\n- Do not promote `.github/workflows/pdf-tunner-webview2-fixed-stage.yml` or diagnostic artifacts into the permanent product workflow/release. The primary `.github/workflows/pdf-tunner-windows-portable.yml` owns the accepted gates.\n- Upstream base identity is the exact snapshot commit `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`, which reports version `2.14.3` in its source metadata. Do not describe that SHA as identical to the separate upstream `v2.14.3` tag object.\n'''
if f"Staging Run `{ACCEPTED_RUN}` is the green acceptance evidence" in agents_text:
    raise SystemExit("AGENTS acceptance note already exists unexpectedly")
agents.write_text(agents_text + agents_note, encoding="utf-8", newline="\n")

subprocess.check_call(["git", "diff", "--check"], cwd=primary)
changed = sorted(line[3:] for line in subprocess.check_output(["git", "status", "--porcelain"], cwd=primary, text=True).splitlines())
expected = sorted([
    ".github/scripts/prepare-webview2-fixed-runtime.ps1",
    ".github/scripts/validate-webview2-fixed-runtime.ps1",
    ".github/workflows/pdf-tunner-windows-portable.yml",
    "AGENTS.md",
    "README.md",
    "frontend/editor/src-tauri/Cargo.toml",
    "frontend/editor/src-tauri/src/main.rs",
])
if changed != expected:
    raise SystemExit(f"Unexpected primary promotion diff: {changed}")

out = helper_root / ".github/diagnostics/generated-webview2-primary"
if out.exists():
    shutil.rmtree(out)
out.mkdir(parents=True)
for rel in expected:
    src = primary / rel
    dst = out / (rel.replace("/", "__") + ".txt")
    shutil.copyfile(src, dst)

subprocess.check_call(["git", "config", "user.name", "WillsitoGG"], cwd=helper_root)
subprocess.check_call(["git", "config", "user.email", "179575519+WillsitoGG@users.noreply.github.com"], cwd=helper_root)
subprocess.check_call(["git", "add", "--", str(out.relative_to(helper_root))], cwd=helper_root)
subprocess.check_call(["git", "commit", "-m", "ci: materialize accepted WebView2 primary promotion"], cwd=helper_root)
subprocess.check_call(["git", "push", "--force", "origin", "HEAD:refs/heads/pdf-tunner/webview2-primary-generated-files"], cwd=helper_root)
print(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=helper_root, text=True).strip())
