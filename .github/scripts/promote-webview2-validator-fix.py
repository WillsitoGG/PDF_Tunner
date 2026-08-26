from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
expected_head = "b50e994430a457afb6f594513a3ae23ad78659dc"

def run(*args):
    return subprocess.check_output(args, cwd=repo, text=True).strip()

actual_head = run("git", "rev-parse", "HEAD")
if actual_head != expected_head:
    raise SystemExit(f"Staging HEAD moved unexpectedly. Expected {expected_head}, got {actual_head}.")

validator = repo / ".github/scripts/validate-webview2-fixed-runtime.ps1"
text = validator.read_text(encoding="utf-8")
old = """if ($provenanceText -notmatch '(?m)^Selector=https://developer\\.microsoft\\.com/en-us/microsoft-edge/webview2\\s*$') {\n  throw 'WebView2 provenance does not identify the official Microsoft selector page.'\n}\n"""
if text.count(old) != 1:
    raise SystemExit(f"Expected exactly one stale Selector provenance assertion, found {text.count(old)}.")
validator.write_text(text.replace(old, ""), encoding="utf-8", newline="\n")

readme = repo / "README.md"
readme_note = """

### WebView2 provenance validator aligned with pinned CAB

The Fixed Runtime preparation path no longer uses the mutable Microsoft developer-page selector; it pins the exact official Microsoft CDN CAB instead. The validator therefore no longer requires the obsolete `Selector=...` provenance line. It continues to require exact version/architecture metadata, an approved Microsoft CDN host, SHA-256 provenance/SHA agreement, the expected CAB filename, runtime completeness and live package-local runtime/profile evidence.
"""
readme.write_text(readme.read_text(encoding="utf-8") + readme_note, encoding="utf-8", newline="\n")

agents = repo / "AGENTS.md"
agents_note = """

### Fixed WebView2 provenance invariant

- Do not reintroduce a `Selector=https://developer.microsoft.com/...` requirement: historical Fixed Runtime `151.0.4129.101` is pinned by exact Microsoft CDN CAB URL and mandatory SHA-256, not resolved from the mutable live selector page.
- Static validation must retain version, architecture, approved CDN host, exact CAB filename via `SHA256SUMS.txt`, provenance/SHA agreement, pinned SHA, runtime completeness and absence of installer/archive payloads. Live validation additionally proves ACLs, package-local Fixed Runtime process selection and `data/webview2` use.
"""
agents.write_text(agents.read_text(encoding="utf-8") + agents_note, encoding="utf-8", newline="\n")

subprocess.check_call(["git", "diff", "--check"], cwd=repo)
changed = sorted(line[3:] for line in subprocess.check_output(["git", "status", "--porcelain"], cwd=repo, text=True).splitlines())
expected = sorted([".github/scripts/validate-webview2-fixed-runtime.ps1", "AGENTS.md", "README.md"])
if changed != expected:
    raise SystemExit(f"Unexpected staging diff: {changed}")

subprocess.check_call(["git", "config", "user.name", "WillsitoGG"], cwd=repo)
subprocess.check_call(["git", "config", "user.email", "179575519+WillsitoGG@users.noreply.github.com"], cwd=repo)
subprocess.check_call(["git", "add", "--", *expected], cwd=repo)
subprocess.check_call(["git", "commit", "-m", "fix(portable): align WebView2 provenance validation"], cwd=repo)
subprocess.check_call(["git", "push", "origin", "HEAD:pdf-tunner/webview2-fixed-v151-final-stage"], cwd=repo)
print(run("git", "rev-parse", "HEAD"))
