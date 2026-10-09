#!/usr/bin/env python3
"""Cheap source-level guard for PDF_Tunner 3.1 native migration.

This intentionally does NOT claim build/runtime success; the full offline
Windows pipeline remains a separate acceptance gate.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
base = json.loads((root / "frontend/editor/src-tauri/tauri.conf.json").read_text())
overlay = json.loads((root / "frontend/editor/src-tauri/tauri.pdf-tunner.conf.json").read_text())
assert base["version"] == "3.1.0", "Build baseline is not upstream Stirling-PDF v3.1.0"
assert overlay["productName"] == overlay["mainBinaryName"] == "PDF_Tunner"
assert overlay["identifier"] == "com.willsitogg.pdf-tunner"
assert overlay["bundle"]["active"] is False, "Portable must not produce MSI/installer"
assert overlay["plugins"]["updater"]["endpoints"][0].startswith(
    "https://github.com/WillsitoGG/PDF_Tunner/"
), "Portable updater still targets the upstream Stirling releases"
checks = {
    "frontend/editor/src-tauri/src/main.rs": [
        "PDF_TUNNER_PORTABLE", "WEBVIEW2_BROWSER_EXECUTABLE_FOLDER",
        "WEBVIEW2_USER_DATA_FOLDER", "JAVA_TOOL_OPTIONS",
    ],
    "frontend/editor/src-tauri/src/lib.rs": [
        "is_pdf_tunner_portable", "window_state_plugin()",
        "log_plugin()", "portable_window_state::save",
    ],
    "frontend/editor/src-tauri/src/utils/paths.rs": [
        "PDF_TUNNER_PORTABLE_ROOT", "portable_data_dir",
    ],
    "frontend/editor/src-tauri/src/utils/portable_window_state.rs": [
        "data", "window-state", "PDF_TUNNER_PORTABLE_ROOT",
    ],
    "frontend/editor/src-tauri/src/commands/backend.rs": [
        "-Dserver.address=127.0.0.1", "-XX:-UsePerfData",
        "STIRLING_PDF_SHUTDOWN_FILE", '.env("TEMP"',
    ],
    "frontend/editor/src-tauri/src/commands/platform.rs": [
        "pub fn is_pdf_tunner_portable",
    ],
    "frontend/editor/src-tauri/Cargo.toml": [
        "Win32_Storage_FileSystem", 'webview2-com = "0.38.2"',
    ],
}
for rel, required in checks.items():
    data = (root / rel).read_text()
    missing = [token for token in required if token not in data]
    if missing:
        raise SystemExit(f"FAIL: {rel}: missing native-portable contracts {missing}")
    print(f"PASS: native source contracts: {rel}")
print("PASS: static v3.1.0 portable migration preflight (not a compiled build)")

# Migration bridge: these former Windows CI files are reference inputs, not v3 acceptance.
source_inputs = (
    ".github/config/ocrmypdf-py312-windows-x64.lock.txt",
    ".github/config/opencv-py312-windows-x64.lock.txt",
    ".github/scripts/audit-host-boundaries.ps1",
    ".github/scripts/collect-startup-diagnostics.ps1",
    ".github/scripts/prepare-branding.ps1",
    ".github/scripts/publish-push-run-statuses.ps1",
    ".github/scripts/rar-probe.rs",
    ".github/scripts/validate-branding.ps1",
    ".github/scripts/validate-portable-window-state.ps1",
)
for rel in source_inputs:
    if not (root / rel).is_file():
        raise SystemExit(f"FAIL: missing Windows CI source input: {rel}")
    print(f"PASS: staged Windows CI source input: {rel}")

gradle = (root / "build.gradle").read_text()
if "modernJavaVersion = 25" not in gradle or "version = '3.1.0'" not in gradle:
    raise SystemExit("FAIL: expected upstream v3.1.0 / JDK 25 Gradle contract")
desktop_tasks = (root / ".taskfiles/desktop.yml").read_text()
for token in ("jlink:jar:", "jlink:runtime:", "jlink:verify:"):
    if token not in desktop_tasks:
        raise SystemExit(f"FAIL: upstream desktop pipeline task missing: {token}")
print("PASS: v3.1.0 uses JDK 25 and upstream desktop JLink/JAR tasks")

# A5 source guard: portable v3.1 must never request upstream updates, even if
# native-mode detection fails. The actual behavior still requires frontend tests.
frontend_guards = {
    "frontend/editor/src/desktop/hooks/useDesktopUpdatePopup.ts": [
        'invoke<boolean>("is_pdf_tunner_portable")',
        'skipping check',
    ],
    "frontend/editor/src/core/services/updateService.ts": [
        'async function isPortablePdfTunner()',
        "if (await isPortablePdfTunner()) return null;",
        'if (await isPortablePdfTunner()) return "";',
    ],
    "frontend/editor/src/desktop/components/shared/config/configSections/GeneralSection.tsx": [
        'invoke<boolean>("is_pdf_tunner_portable")',
        "!isPortable && <DefaultAppSettings />",
        "isPortable ||",
    ],
}
for rel, tokens in frontend_guards.items():
    data = (root / rel).read_text()
    for token in tokens:
        if token not in data:
            raise SystemExit(f"FAIL: missing portable frontend update guard in {rel}: {token}")
    print(f"PASS: portable frontend update source guard: {rel}")

# A7: keep account wizard and local account buttons off the marked portable UI.
for rel, required in {
    "frontend/editor/src/desktop/components/DesktopOnboardingModal.tsx": [
        'invoke<boolean>("is_pdf_tunner_portable")',
        "if (isPortable || bypassOnboarding) return null;",
    ],
    "frontend/editor/src/desktop/components/ConnectionSettings.tsx": [
        'invoke<boolean>("is_pdf_tunner_portable")',
        "!isPortable && (",
        "onClick={handleSignIn}",
    ],
}.items():
    data = (root / rel).read_text()
    for token in required:
        if token not in data:
            raise SystemExit(f"FAIL: missing portable account UI guard: {rel}: {token}")
    print(f"PASS: portable account UI source guard: {rel}")

# A9: ensure the candidate v3.1 full Windows pipeline has not silently dropped
# the former acceptance gates or changed its pinned runtime provenance.
candidate = root / ".github/config/pdf-tunner-v3-windows-portable.candidate.yml"
acceptance = candidate.read_text()
if 'PDF_TUNNER_UPSTREAM_VERSION: "3.1.0"' not in acceptance:
    raise SystemExit("FAIL: Windows v3 acceptance not pinned to official 3.1.0")
if 'PDF_TUNNER_UPSTREAM_COMMIT: "b99fa929e365760c863956bf23c127b098c288e5"' not in acceptance:
    raise SystemExit("FAIL: Windows v3 acceptance upstream SHA differs")
if "pdf-tunner/windows-portable-v1" in acceptance or 'PDF_TUNNER_UPSTREAM_VERSION: "2.14.3"' in acceptance:
    raise SystemExit("FAIL: Windows acceptance still selects old v2 branch/version")
if '  push:' in acceptance:
    raise SystemExit("FAIL: candidate CI must be manual-only, no push event")
required_acceptance_gates = [
    "Prepare official Stirling desktop build",
    "Run official Tauri/Cargo tests",
    "Build PDF_Tunner Tauri executable without installer",
    "Validate assembled PDF_Tunner branding",
    "Validate bundled LibreOffice and unoconvert",
    "Stage portable Python, OCRmyPDF and NumPy",
    "Start PDF_Tunner and validate real backend",
    "Validate portable window-state persistence and second-launch restore",
    "Audit actual Windows process TCP and scoped host state",
    "Create portable ZIP and SHA-256",
    "Upload lightweight CI evidence",
]
for required in required_acceptance_gates:
    if required not in acceptance:
        raise SystemExit(f"FAIL: Windows v3 acceptance gate missing: {required}")
for pin in (
    "c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda",
    "dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5",
    "993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5",
):
    if pin not in acceptance:
        raise SystemExit("FAIL: pinned WebView2/qpdf/Poppler dependency hash missing")
print("PASS: staged Windows v3.1 acceptance draft retains critical gates and SHA pins")

# A10 interim branding audit: matching v2 SVG blobs stage the existing
# PDF_Tunner visual identity without inventing the pending blue logo.
brand_assets = (
    "icon-light.svg", "icon-dark.svg", "wordmark-black.svg",
    "wordmark-grey.svg", "wordmark-white.svg",
)
for name in brand_assets:
    file = root / "frontend/editor/public/pdf-tunner" / name
    if not file.is_file():
        raise SystemExit(f"FAIL: portable branded static SVG missing: {file}")
for rel, tokens in {
    "frontend/editor/src/core/ui/Logo.tsx": ["/pdf-tunner/icon-light.svg", "/pdf-tunner/wordmark-black.svg", 'alt = "PDF_Tunner"'],
    "frontend/editor/src/core/components/shared/BrandMark.tsx": ["/pdf-tunner/icon-light.svg", 'aria-label="PDF_Tunner"'],
    "frontend/editor/index.html": ["<title>PDF_Tunner</title>", "pdf-tunner/icon-light.svg"],
    "frontend/editor/public/manifest.json": ['"name": "PDF_Tunner"', "pdf-tunner/icon-light.svg"],
}.items():
    data = (root / rel).read_text()
    for token in tokens:
        if token not in data:
            raise SystemExit(f"FAIL: portable frontend branding source missing: {rel}: {token}")
print("PASS: interim legacy PDF_Tunner visual identity is staged for v3.1")

# A11: do not regress v3's desktop SaaS-only billing hook or the real
# PowerShell Windows branding QA. This is source-only until the Windows ZIP gate.
wallet = (root / "frontend/editor/src/desktop/hooks/useWallet.ts").read_text()
for token in ("useConfirmedSaaSMode", "enabled && saasMode"):
    if token not in wallet:
        raise SystemExit(f"FAIL: v3 billing hook no longer restricted to SaaS mode: {token}")
branding_gate = (root / ".github/scripts/validate-branding.ps1").read_text()
for token in (
    "useConfirmedSaaSMode", "enabled && saasMode",
    "if \\(isPortable \\|\\| bypassOnboarding\\) return null",
    "is_pdf_tunner_portable",
):
    if token not in branding_gate:
        raise SystemExit(f"FAIL: Windows branding QA source lacks v3 account gate: {token}")
print("PASS: v3.1 Windows branding QA references active account/billing guard APIs")

# A12: upstream v3 dynamically creates the main Tauri window in Rust. The
# v2 config-defined default "main" window would duplicate that native label.
if overlay.get("app", {}).get("windows") != []:
    raise SystemExit("FAIL: v3 portable overlay must not auto-create a Tauri main window")
windows_native = (root / "frontend/editor/src-tauri/src/commands/window.rs").read_text()
if windows_native.count('std::env::var_os("PDF_TUNNER_PORTABLE_ROOT")') < 2:
    raise SystemExit("FAIL: main/spawned Rust windows lack native portable detection")
if windows_native.count('"PDF_Tunner"') < 2:
    raise SystemExit("FAIL: main/spawned Rust windows lack PDF_Tunner branding")
print("PASS: v3 native window creation is unique and portable window titles are branded")

# A13: v3's workspace places the Tauri config schema in frontend/node_modules.
if overlay.get("$schema") != "../../node_modules/@tauri-apps/cli/config.schema.json":
    raise SystemExit("FAIL: v3 Tauri portable overlay schema points to old v2 node_modules")
