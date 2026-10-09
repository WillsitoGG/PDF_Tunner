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
