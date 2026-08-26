from pathlib import Path
import shutil
import subprocess
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: integrate-webview2-stage.py <staging-checkout> <primary-checkout>")

src = Path(sys.argv[1]).resolve()
dst = Path(sys.argv[2]).resolve()
EXPECTED_STAGING = "dc176ccf38a9f8b4489216119bf648d010e19349"
EXPECTED_PRIMARY = "0e56e5b3a8113012f2f5ceb620fcfbeecbaa4eea"
STAGING_RUN = "32965658540"


def git(repo, *args):
    return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()

if git(src, "rev-parse", "HEAD") != EXPECTED_STAGING:
    raise SystemExit("Unexpected staging HEAD; integration refused.")
if git(dst, "rev-parse", "HEAD") != EXPECTED_PRIMARY:
    raise SystemExit("Unexpected primary HEAD; integration refused.")

for rel in [
    ".github/scripts/prepare-webview2-fixed-runtime.ps1",
    ".github/scripts/validate-webview2-fixed-runtime.ps1",
    "frontend/editor/src-tauri/Cargo.toml",
    "frontend/editor/src-tauri/src/main.rs",
    "README.md",
    "AGENTS.md",
]:
    source = src / rel
    target = dst / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

workflow_path = dst / ".github/workflows/pdf-tunner-windows-portable.yml"
workflow = workflow_path.read_text(encoding="utf-8")

env_anchor = '  PDF_TUNNER_UPSTREAM_COMMIT: "7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632"\n  CI: "true"'
env_replacement = '''  PDF_TUNNER_UPSTREAM_COMMIT: "7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632"
  PDF_TUNNER_WEBVIEW2_FIXED_VERSION: "151.0.4129.101"
  PDF_TUNNER_WEBVIEW2_FIXED_ARCH: "x64"
  PDF_TUNNER_WEBVIEW2_FIXED_URL: "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/d480b710-fe1e-4e4d-ae99-5b62e6391fd3/Microsoft.WebView2.FixedVersionRuntime.151.0.4129.101.x64.cab"
  PDF_TUNNER_WEBVIEW2_FIXED_SHA256: "c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda"
  CI: "true"'''
if workflow.count(env_anchor) != 1:
    raise SystemExit("Primary workflow env anchor mismatch.")
workflow = workflow.replace(env_anchor, env_replacement)

java_anchor = "      - name: Validate bundled Java runtime\n"
webview_static = '''      - name: Stage official Microsoft Fixed WebView2 Runtime
        shell: pwsh
        run: |
          & './.github/scripts/prepare-webview2-fixed-runtime.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -Version $env:PDF_TUNNER_WEBVIEW2_FIXED_VERSION `
            -Architecture $env:PDF_TUNNER_WEBVIEW2_FIXED_ARCH `
            -DownloadUrl $env:PDF_TUNNER_WEBVIEW2_FIXED_URL `
            -ExpectedSha256 $env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256

      - name: Validate staged Fixed WebView2 metadata and tree
        shell: pwsh
        run: |
          & './.github/scripts/validate-webview2-fixed-runtime.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -Version $env:PDF_TUNNER_WEBVIEW2_FIXED_VERSION `
            -Architecture $env:PDF_TUNNER_WEBVIEW2_FIXED_ARCH `
            -ExpectedCabSha256 $env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256

'''
if workflow.count(java_anchor) != 1:
    raise SystemExit("Primary workflow Java anchor mismatch.")
workflow = workflow.replace(java_anchor, webview_static + java_anchor)

health_anchor = '          Write-Host "Backend health check OK: $statusUri"\n\n'
webview_live = '''          Write-Host "Backend health check OK: $statusUri"

          & './.github/scripts/validate-webview2-fixed-runtime.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -Version $env:PDF_TUNNER_WEBVIEW2_FIXED_VERSION `
            -Architecture $env:PDF_TUNNER_WEBVIEW2_FIXED_ARCH `
            -ExpectedCabSha256 $env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256 `
            -RequireLiveProcess
          if ($LASTEXITCODE -ne 0) { throw 'Fixed WebView2 live validation failed.' }

'''
if workflow.count(health_anchor) != 1:
    raise SystemExit("Primary workflow health anchor mismatch.")
workflow = workflow.replace(health_anchor, webview_live)

clean_anchor = "      - name: Clean runtime data and verify portable layout\n"
final_webview_checks = '''      - name: Require pinned Fixed WebView2 CAB SHA before accepting package
        shell: pwsh
        run: |
          $provenance = Join-Path $PWD 'dist/PDF_Tunner/runtime/webview2/PROVENANCE.txt'
          Write-Host 'Fixed WebView2 provenance:'
          Get-Content -LiteralPath $provenance
          if ([string]::IsNullOrWhiteSpace($env:PDF_TUNNER_WEBVIEW2_FIXED_SHA256)) {
            throw 'Fixed WebView2 CAB SHA-256 is not pinned.'
          }

      - name: Verify portable layout contains no downloaded CAB
        shell: pwsh
        run: |
          $portable = Resolve-Path './dist/PDF_Tunner'
          $cabs = @(Get-ChildItem -LiteralPath $portable -Recurse -Force -File -Filter '*.cab' -ErrorAction SilentlyContinue)
          if ($cabs.Count -gt 0) {
            $cabs | Select-Object FullName, Length | Format-Table -AutoSize
            throw 'Downloaded WebView2 CAB leaked into the portable package.'
          }
          Write-Host 'PASS: package contains normalized Fixed WebView2 runtime only; no CAB archive remains.'

'''
if workflow.count(clean_anchor) != 1:
    raise SystemExit("Primary workflow clean-layout anchor mismatch.")
workflow = workflow.replace(clean_anchor, final_webview_checks + clean_anchor)

required_anchor = "            'runtime/jre/bin/java.exe',\n            'data'"
required_replacement = "            'runtime/jre/bin/java.exe',\n            'runtime/webview2/fixed/msedgewebview2.exe',\n            'runtime/webview2/PROVENANCE.txt',\n            'runtime/webview2/SHA256SUMS.txt',\n            'data'"
if workflow.count(required_anchor) != 1:
    raise SystemExit("Primary workflow required-layout anchor mismatch.")
workflow = workflow.replace(required_anchor, required_replacement)
workflow_path.write_text(workflow, encoding="utf-8", newline="\n")

readme_path = dst / "README.md"
readme = readme_path.read_text(encoding="utf-8")
old_status = '- Status: **AppData containment is CI-proven. Fixed WebView2 Runtime `151.0.4129.101` x64 is now pinned for staging to the verified Microsoft CDN CAB with SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`; full assembled-package acceptance is the current gate.**'
new_status = f'- Status: **AppData containment is CI-proven. Fixed WebView2 Runtime `151.0.4129.101` x64 is pinned to the verified Microsoft CDN CAB and is staging-proven by Actions Run `{STAGING_RUN}`; the permanent Windows portable workflow now carries the same gates for primary-branch acceptance.**'
if old_status not in readme:
    raise SystemExit("README status anchor mismatch.")
readme = readme.replace(old_status, new_status)
readme += f'''\n\n### Fixed WebView2 staging acceptance — Run `{STAGING_RUN}`\n\nActions Run `{STAGING_RUN}` is the acceptance run for the staging implementation promoted to the permanent Windows portable workflow. It must be green before this integrator is executed. The promoted implementation pins Microsoft Edge WebView2 Fixed Runtime `151.0.4129.101` x64 by exact Microsoft CDN CAB URL and SHA-256, validates the normalized runtime and provenance, applies the Windows 10 AppContainer read/execute ACLs, proves the live WebView2 process runs from `runtime/webview2/fixed`, keeps its user profile under `data/webview2`, reruns the complete AppData/two-launch window-state proof and rejects a CAB archive in the final portable tree.\n\nThe fork's pinned source snapshot remains `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`. That commit itself declares application version `2.14.3` in `build.gradle`; the official Git tag `v2.14.3` resolves to a different upstream commit (`e556eba8326c8349aa0318034cfdb5c442dca21c`). PDF_Tunner keeps its original snapshot for v1 reproducibility rather than silently retargeting the codebase.\n'''
readme_path.write_text(readme, encoding="utf-8", newline="\n")

agents_path = dst / "AGENTS.md"
agents = agents_path.read_text(encoding="utf-8")
agents += f'''\n\n### Fixed WebView2 staging acceptance and promotion\n\n- Staging acceptance run: `{STAGING_RUN}` on staging HEAD `{EXPECTED_STAGING}`. Do not treat this phase as accepted unless that run is actually green.\n- Permanent integration copies only the two WebView2 scripts and the required Tauri `Cargo.toml`/`main.rs` changes; the staging workflow itself is temporary and must never be promoted as the primary workflow.\n- The permanent `.github/workflows/pdf-tunner-windows-portable.yml` must stage the pinned CAB, validate static provenance/tree, validate the live package-local Fixed Runtime process/profile, rerun AppData/window-state containment, require the pinned SHA and reject CAB residue before packaging.\n- Source-version precision: pinned snapshot `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632` declares `2.14.3` in its own `build.gradle`, but upstream tag `v2.14.3` resolves to `e556eba8326c8349aa0318034cfdb5c442dca21c`. Keep the original snapshot unless a deliberate future upstream-update task changes it; never rewrite the base merely to make the tag name and snapshot SHA coincide.\n'''
agents_path.write_text(agents, encoding="utf-8", newline="\n")

subprocess.check_call(["git", "diff", "--check"], cwd=dst)
changed = sorted(line[3:] for line in subprocess.check_output(["git", "status", "--porcelain"], cwd=dst, text=True).splitlines())
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
    raise SystemExit(f"Unexpected integration diff: {changed}")

subprocess.check_call(["git", "config", "user.name", "WillsitoGG"], cwd=dst)
subprocess.check_call(["git", "config", "user.email", "179575519+WillsitoGG@users.noreply.github.com"], cwd=dst)
subprocess.check_call(["git", "add", "--", *expected], cwd=dst)
subprocess.check_call(["git", "commit", "-m", "feat(portable): integrate Fixed WebView2 runtime"], cwd=dst)
subprocess.check_call(["git", "push", "origin", "HEAD:pdf-tunner/windows-portable-v1"], cwd=dst)
print(git(dst, "rev-parse", "HEAD"))
