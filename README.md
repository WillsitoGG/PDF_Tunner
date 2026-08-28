# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Focused LibreOffice branch: `pdf-tunner/libreoffice-candidate`
- Target: **Windows 10/11 x64 portable ZIP**
- No final PDF_Tunner v1 Release exists yet; `main` remains the clean upstream base during portable development.

## Accepted portable layers

The complete primary Windows workflow has accepted:

- native Tauri/JRE portable bootstrap, package-local backend state, Java temp, WebView2 profile, Tauri stores/logs/cookies/window state and shutdown containment;
- Fixed WebView2 `151.0.4129.101` x64;
- qpdf `12.4.0` MinGW64;
- ImageMagick `7.1.2-30` portable Q16 x64;
- Ghostscript `10.07.1` Win64;
- Tesseract OCR release `5.5.3`, Windows CLI `5.5.3.20260724`, with pinned `eng`, `spa` and `osd` models;
- Python `3.12.14` x64 + OCRmyPDF `17.10.0` with a relocatable package-local launcher.

### Python + OCRmyPDF — accepted in primary Run #77

Pins:

- Python `3.12.14` x64 from `astral-sh/python-build-standalone`, release `20260825`, `install_only_stripped` Windows MSVC archive;
- Python archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` from PyPI;
- OCRmyPDF wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

The normal pip Windows launcher is replaced by a native relative `tools/python/ocrmypdf.exe` shim that resolves the sibling `python.exe`, runs `python.exe -m ocrmypdf`, directs OCRmyPDF temp state to `data/tmp/ocrmypdf/`, and directs Python bytecode cache to `data/python-cache/`.

Primary Run **`33201568275` (#77)**, job **`98952028665`**, commit **`54802c15427673c0e95738195947ab76239d6e31`**, completed fully green with every previously accepted gate still enabled. It proved package-only Python/OCRmyPDF resolution, real searchable-PDF OCR, relocation to a path containing spaces, real PDF_Tunner backend acceptance without `Missing dependency: ocrmypdf` / OCRmyPDF group disablement, portable state/process containment, final clean layout, ZIP/SHA creation and artifact upload.

Validated artifact: **`9710851673`**, `PDF_Tunner-Windows-x64-Portable-bootstrap`, Actions digest **`sha256:96d914e252505efa26327c16316903740b0e1216e526d0721efb448c3738ae2e`**.

Focused Run `33169895080` (#5), job `98844184266`, remains useful diagnostic/candidate evidence but is superseded for acceptance by primary Run #77.

## Active candidate: LibreOffice

Stirling 2.14.3 probes `soffice` directly for LibreOffice and probes `unoconvert` independently for UNO conversion. LibreOffice is therefore being gated first; UNO/Unoconvert remains a separate subsequent block.

Current LibreOffice candidate:

- LibreOffice **`26.8.0.3`** x64;
- official The Document Foundation MSI: `LibreOffice_26.8.0_Win_x86-64.msi`;
- MSI SHA-256 **`4AA6C6E1895F4055104EFFCB556BD3362D20C6AD707C149543304F395EF9DB95`**;
- extracted as a Windows Installer administrative image (`/a`) rather than installed on the CI host;
- canonical vendor executable under `tools/libreoffice/program/soffice.exe`;
- native relative Stirling-facing shim under `tools/bin/soffice.exe`, which localizes LibreOffice `TEMP`/`TMP` to `data/tmp/libreoffice/`;
- validation requires isolated package-only command resolution, exact provenance/hash checks, real headless HTML -> PDF conversion, no newly-created host `%APPDATA%/LibreOffice` profile, no orphan `soffice` process and a second real conversion after relocating the whole portable tree to a path containing spaces.

Stirling's Office fallback already supplies a unique `-env:UserInstallation=...` profile under Java temp; PDF_Tunner already redirects Java temp into package-local `data/tmp/`. The focused candidate deliberately does **not** claim UNO/Unoconvert support.

The Windows LibreOffice distribution declares a Microsoft Visual C++ 2015+ x64 runtime dependency. The candidate gate tests the vendor files and portable state behavior on GitHub's Windows runner; clean-machine v1 acceptance must still establish whether the VC runtime needs to be bundled or can be treated as an operating-system prerequisite.

## Architecture

PDF_Tunner uses Stirling's own Tauri desktop app in `frontend/editor/src-tauri`. The old `PDF_Tunner_Legacy` .NET/WebView2 launcher is reference material only.

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`. State is localized component by component instead of globally replacing Windows profile variables before Tauri/WebView2 initialization:

- Stirling backend config/logs/working state -> `data/`;
- Java temp -> `data/tmp/`;
- WebView2 profile -> `data/webview2/`;
- Tauri logs/store/cookies/window state -> `data/tauri/...`;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- Tesseract models -> `tools/tesseract/tessdata/`;
- Python/OCRmyPDF -> `tools/python/`; OCRmyPDF temp -> `data/tmp/ocrmypdf/`; Python cache -> `data/python-cache/`;
- LibreOffice candidate -> `tools/libreoffice/`; Stirling-facing shim -> `tools/bin/soffice.exe`; LibreOffice temp -> `data/tmp/libreoffice/`;
- Calibre config -> `data/calibre/` when Calibre is added.

Portable mode also skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## External dependency source of truth

The dependency inventory is source-backed from Stirling 2.14.3, especially `ExternalAppDepConfig`, `RuntimePathConfig`, the Docker toolchain and controllers/services that execute each feature.

| Capability | Stirling runtime probe |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` (minimum 58) |
| Poppler HTML conversion | `pdftohtml` |
| UNO conversion | `unoconvert` |
| qpdf | `qpdf` (minimum 12) |
| Tesseract | `tesseract` |
| CBR/RAR | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |

Also audit Poppler helpers (`pdfinfo`, `pdfimages`), `unpaper`, `pngquant`, NumPy/OpenCV, WeasyPrint, LibreOffice/UNO, Calibre, conversion fonts, VeraPDF E2E, `jbig2enc` and any additional exact dependency exposed by pinned source.

## Validation contract

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency is accepted only when the **complete current primary workflow** is green with every earlier accepted gate still enabled. A focused candidate workflow is only evidence for promotion; `--version` alone is never sufficient. Real operations and isolated package-first PATH/environment are required wherever technically practical.

## Remaining v1 roadmap

1. Pass the focused LibreOffice gate, promote it to the primary workflow and obtain full primary acceptance.
2. Retire focused OCRmyPDF/LibreOffice workflows when no longer needed.
3. Complete external toolchain: UNO/Unoconvert or source-compatible portable alternative; Poppler (`pdftohtml`, `pdfinfo`, `pdfimages`); portable Python dependency consolidation; NumPy; OpenCV; WeasyPrint; Calibre; `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate `jbig2enc`; establish viable RAR/CBR support or document the concrete limitation; add any further dependency found in exact pinned source.
4. Representative E2E operations across OCR, Office, HTML/URL -> PDF, Poppler, WeasyPrint, Calibre/EPUB, Python/OpenCV and representative Stirling API families.
5. Non-Enterprise parity audit against Stirling 2.14.3.
6. Final branding and portability/state/process audits.
7. CI/repository cleanup and final downstream diff hygiene review.
8. Final docs/provenance/version/hash record.
9. Integrate to `main` without reopening old PR #1.
10. Publish the clean v1 portable ZIP only after all gates, then perform the manual clean-machine Windows 10/11 checklist.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**
