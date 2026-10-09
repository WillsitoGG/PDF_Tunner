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
