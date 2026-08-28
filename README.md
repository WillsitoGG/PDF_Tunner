# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- No final PDF_Tunner v1 Release exists yet; `main` remains the clean upstream base during portable development.

### Accepted portable layers

The complete primary Windows workflow has accepted:

- native Tauri/JRE portable bootstrap, package-local backend state, Java temp, WebView2 profile, Tauri stores/logs/cookies/window state and shutdown containment;
- Fixed WebView2 `151.0.4129.101` x64;
- qpdf `12.4.0` MinGW64;
- ImageMagick `7.1.2-30` portable Q16 x64;
- Ghostscript `10.07.1` Win64;
- Tesseract OCR release `5.5.3`, Windows CLI `5.5.3.20260724`, with pinned `eng`, `spa` and `osd` models.

Tesseract acceptance evidence is primary Run **`33122172947` (#70)**, job `98691480028`, commit `52429eb7812e8615ee39aab695641d495798c1ba`. The whole workflow passed with every earlier gate still enabled. Its short-lived CI artifact was `9667429758`, Actions digest `sha256:12943b1b38ac7660156667acbaf5a0d3ccae189d0f9d28be97fe32b0db8326aa`.

Primary Run **`33169895113` (#76)**, job `98844184305`, commit `9f0dcb4cb35cb73a1ceadf2ebe105ec23c5fd3c8`, is the latest fully green baseline before OCRmyPDF is promoted into the primary workflow. It reconfirmed all accepted layers, real backend startup, portable window-state restore, clean shutdown, ZIP creation and SHA-256.

### OCRmyPDF: focused gate passed; primary integration in progress

Stirling 2.14.3 probes and executes the external command `ocrmypdf`, so the portable product must expose a real executable path while remaining relocatable.

The candidate pins:

- Python `3.12.14` x64 from `astral-sh/python-build-standalone`, release `20260825`, `install_only_stripped` Windows MSVC archive;
- Python archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` from PyPI;
- OCRmyPDF wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

The normal `pip` Windows console launcher is not trusted for relocation because it can capture the interpreter path used during installation. PDF_Tunner removes it and builds a small native `tools/python/ocrmypdf.exe` shim that resolves the sibling `python.exe`, runs `python.exe -m ocrmypdf`, directs OCRmyPDF temp state to `data/tmp/ocrmypdf/`, and directs Python bytecode cache to `data/python-cache/`.

Focused Run **`33169895080` (#5)**, job `98844184266`, commit `9f0dcb4cb35cb73a1ceadf2ebe105ec23c5fd3c8`, is **green candidate evidence**. It proved:

- exact pinned Python/OCRmyPDF versions and hashes;
- AMD64 Python and native relative launcher;
- canonical dependency inventory and clean `pip check`;
- isolated package-only resolution of `python`, `ocrmypdf`, `gs` and `tesseract`;
- real image -> searchable PDF OCR;
- searchable text extraction using OCRmyPDF's bundled `pdfminer-six` dependency;
- package-local OCRmyPDF temp/Python cache;
- a second complete OCR operation after relocation to a path containing spaces.

Earlier focused Runs #1, #2 and #4 were diagnostic only and successively exposed a non-canonical `pip freeze` local-wheel record, synthetic fixture DPI, and an alpha-channel fixture. Those test-only issues were corrected with canonical `pip list --format=freeze`, explicit `--image-dpi 300`, and a 24-bit RGB fixture.

The green focused run does **not** by itself accept OCRmyPDF. This revision promotes the same pinned Python/OCRmyPDF layer into `.github/workflows/pdf-tunner-windows-portable.yml`. Acceptance requires the complete primary workflow to pass with all earlier gates still enabled, the real PDF_Tunner backend not reporting `Missing dependency: ocrmypdf`, real OCR succeeding from the packaged toolchain, relocation succeeding, final layout validation succeeding, and the resulting ZIP/SHA being created.

## Architecture

PDF_Tunner uses Stirling's own Tauri desktop app in `frontend/editor/src-tauri`. The old `PDF_Tunner_Legacy` .NET/WebView2 launcher is reference material only.

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`. PDF_Tunner does not globally replace Windows profile variables before Tauri/WebView2 initialization; state is localized component by component:

- Stirling backend config/logs/working state -> `data/`;
- Java temp -> `data/tmp/`;
- WebView2 profile -> `data/webview2/`;
- Tauri logs/store/cookies/window state -> `data/tauri/...`;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- Tesseract models -> `tools/tesseract/tessdata/` through `TESSDATA_PREFIX`;
- Python/OCRmyPDF -> `tools/python/`;
- OCRmyPDF temp -> `data/tmp/ocrmypdf/`;
- Python cache -> `data/python-cache/`;
- Calibre config -> `data/calibre/` when Calibre is added.

Portable mode also skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## Intended portable layout

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  UPSTREAM_BASE.txt
  libs/
  runtime/
    jre/
    webview2/fixed/
  tools/
    qpdf/
    imagemagick/
    ghostscript/
    tesseract/
      tessdata/
    python/
      python.exe
      ocrmypdf.exe
      Scripts/
      Lib/
      PROVENANCE.txt
      SHA256SUMS.txt
      PYTHON_VERSION.txt
      OCRMY_PDF_VERSION.txt
      DEPENDENCIES.txt
  data/
```

`data/` is runtime state and must not be committed or shipped pre-populated in the final clean ZIP.

## External dependency source of truth

The dependency inventory is source-backed from Stirling 2.14.3, especially `ExternalAppDepConfig`, `RuntimePathConfig`, the Docker toolchain and the controllers/services that execute each feature.

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

The pinned source/toolchain also exposes Poppler helpers (`pdfinfo`, `pdfimages`), `unpaper`, `pngquant`, LibreOffice/UNO infrastructure, Python, NumPy/OpenCV, WeasyPrint, Calibre, conversion fonts and related tooling. None is considered supported merely because the desktop application starts.

## Validation contract

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

During active development it has one branch-scoped `push` trigger plus `workflow_dispatch`, with `concurrency` and `cancel-in-progress: true`. Development-only push/status/focused mechanisms must be removed before final integration to `main`.

A dependency is accepted only when the **complete current primary workflow** is green. `--version` alone is never sufficient: where practical CI must execute a real operation with isolated PATH/environment proving that runner-installed software is not satisfying the test.

## Remaining v1 roadmap

1. Obtain complete primary acceptance for Python + OCRmyPDF, then remove the focused OCRmyPDF workflow when it is no longer needed.
2. Complete external toolchain: LibreOffice; UNO/Unoconvert or a source-compatible portable alternative; Poppler (`pdftohtml`, `pdfinfo`, `pdfimages`); portable Python dependency consolidation; NumPy; OpenCV; WeasyPrint; Calibre; `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate `jbig2enc`; establish viable RAR/CBR support or document the concrete limitation; add any further dependency found in exact pinned source.
3. Representative E2E operations across OCR, Office, HTML/URL -> PDF, Poppler, WeasyPrint, Calibre/EPUB, Python/OpenCV and representative Stirling API families.
4. Non-Enterprise parity audit against Stirling 2.14.3.
5. Final branding audit: executable/product/window strings, UI, icons/logos, metadata, updater behavior and ZIP/Release names.
6. Final portability audit: AppData, TEMP, registry, WebView2, Tauri state, each external tool's config/cache/temp state and child processes.
7. CI/repository cleanup and final downstream diff hygiene review.
8. Final docs/provenance/version/hash record.
9. Integrate to `main` without reopening old PR #1.
10. Publish the clean v1 portable ZIP only after all gates, then perform the manual clean-machine Windows 10/11 checklist.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**
