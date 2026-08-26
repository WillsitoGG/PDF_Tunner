from pathlib import Path
import shutil
import subprocess
import sys

staging = Path(sys.argv[1]).resolve()
helper_root = Path(__file__).resolve().parents[2]
source_path = helper_root / ".github/scripts/promote-webview2-validator-fix.py"
source = source_path.read_text(encoding="utf-8")
marker = 'subprocess.check_call(["git", "config", "user.name", "WillsitoGG"], cwd=repo)'
if source.count(marker) != 1:
    raise SystemExit(f"Expected exactly one commit/push marker in source helper, found {source.count(marker)}")

# Reuse the already-tested transformation and stop immediately before its
# local staging commit/push. This leaves the exact desired files materialized
# in the staging checkout without requiring workflow-write permission.
prefix = source.split(marker, 1)[0]
old_argv = sys.argv[:]
try:
    sys.argv = [str(source_path), str(staging)]
    exec(compile(prefix, str(source_path), "exec"), {"__name__": "__main__", "__file__": str(source_path)})
finally:
    sys.argv = old_argv

out = helper_root / ".github/diagnostics/generated-webview2-live"
if out.exists():
    shutil.rmtree(out)
out.mkdir(parents=True)

mapping = {
    staging / ".github/workflows/pdf-tunner-webview2-fixed-stage.yml": out / "pdf-tunner-webview2-fixed-stage.yml.txt",
    staging / "README.md": out / "README.md.txt",
    staging / "AGENTS.md": out / "AGENTS.md.txt",
}
for src, dst in mapping.items():
    shutil.copyfile(src, dst)

subprocess.check_call(["git", "config", "user.name", "WillsitoGG"], cwd=helper_root)
subprocess.check_call(
    ["git", "config", "user.email", "179575519+WillsitoGG@users.noreply.github.com"],
    cwd=helper_root,
)
subprocess.check_call(["git", "add", "--", str(out.relative_to(helper_root))], cwd=helper_root)
subprocess.check_call(
    ["git", "commit", "-m", "ci: materialize WebView2 live diagnostic patch blobs"],
    cwd=helper_root,
)
subprocess.check_call(
    [
        "git",
        "push",
        "--force",
        "origin",
        "HEAD:refs/heads/pdf-tunner/webview2-live-generated-files",
    ],
    cwd=helper_root,
)
print(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=helper_root, text=True).strip())
