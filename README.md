# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
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
- Python `3.12.14` x64 portable runtime;
- OCRmyPDF `17.10.0` with a package-relative native launcher.

### Python + OCRmyPDF — accepted

Stirling 2.14.3 probes and executes the external command `ocrmypdf`. PDF_Tunner packages:

- Python `3.12.14` x64 from `astral-sh/python-build-standalone`, release `20260825`, `install_only_stripped` Windows MSVC archive;
- Python archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` from PyPI;
- OCRmyPDF wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

PDF_Tunner removes the pip-generated Windows console launcher and builds `tools/python/ocrmypdf.exe`, a native relative shim that resolves sibling `python.exe`, executes `python.exe -m ocrmypdf`, writes OCRmyPDF temp state to `data/tmp/ocrmypdf/`, and Python cache to `data/python-cache/`.

Primary Run **`33201568275` (#77)**, job **`98952028665`**, commit **`54802c15427673c0e95738195947ab76239d6e31`**, completed successfully with every prior gate enabled. It proved exact pinned versions/hashes, isolated package-only resolution, real searchable-PDF OCR, text extraction, package-local temp/cache, relocation to a path containing spaces, real backend acceptance of `ocrmypdf`, final layout cleanup, ZIP creation and SHA-256.

Run #77 artifact: **`9698621272`**, `PDF_Tunner-Windows-x64-Portable-bootstrap`, GitHub Actions digest **`sha256:68f69bb0d4ed6b731aefee82abff3eba7b01d18c5b270051e2e546337cd6a164`**. This is CI evidence only, not the final v1 Release.

The temporary focused OCRmyPDF workflow has been retired from automatic execution after primary acceptance. It remains manual-only temporarily and must be physically removed during final CI cleanup.

## Architecture

PDF_Tunner uses Stirling's own Tauri desktop app in `frontend/editor/src-tauri`. Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`.

State is localized component by component:

- Stirling backend config/logs/working state -> `data/`;
- Java temp -> `data/tmp/`;
- WebView2 profile -> `data/webview2/`;
- Tauri logs/store/cookies/window state -> `data/tauri/...`;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- Tesseract models -> `tools/tesseract/tessdata/`;
- Python/OCRmyPDF -> `tools/python/`;
- OCRmyPDF temp -> `data/tmp/ocrmypdf/`;
- Python cache -> `data/python-cache/`;
- Calibre config -> `data/calibre/` when added.

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

A dependency is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. `--version` alone is never sufficient.

## Remaining v1 roadmap

1. **LibreOffice + UNO/unoconvert** portable integration and real Office conversion gate.
2. Poppler (`pdftohtml`, `pdfinfo`, `pdfimages`).
3. Consolidate portable Python dependency lock; NumPy; OpenCV; WeasyPrint.
4. Calibre/`ebook-convert`; `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate `jbig2enc`; establish viable RAR/CBR support or document the limitation; add any further dependency found in exact pinned source.
5. Representative E2E operations across OCR, Office, HTML/URL -> PDF, Poppler, WeasyPrint, Calibre/EPUB, Python/OpenCV and representative Stirling API families.
6. Non-Enterprise parity audit against Stirling 2.14.3.
7. Final branding and portability audits.
8. CI/repository cleanup, including physical removal of the retired OCRmyPDF candidate workflow, and downstream diff hygiene review.
9. Final docs/provenance/version/hash record.
10. Integrate to `main` without reopening old PR #1.
11. Publish the clean v1 portable ZIP only after all gates, then perform the manual clean-machine Windows 10/11 checklist.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**
