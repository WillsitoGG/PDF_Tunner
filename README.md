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
- **Tesseract OCR release `5.5.3`, Windows CLI `5.5.3.20260724`, with pinned `eng`, `spa` and `osd` models.**

Tesseract acceptance evidence is primary Run **`33122172947` (#70)**, job `98691480028`, commit `52429eb7812e8615ee39aab695641d495798c1ba`. The whole workflow passed with every earlier gate still enabled. Its short-lived CI artifact was `9667429758`, Actions digest `sha256:12943b1b38ac7660156667acbaf5a0d3ccae189d0f9d28be97fe32b0db8326aa`.

### Active candidate: portable Python + OCRmyPDF

The next block is OCRmyPDF. Stirling 2.14.3 probes and executes the literal external command `ocrmypdf`, so the portable product must expose a real executable path while still remaining relocatable.

The first candidate pins:

- Python `3.12.14` x64 from `astral-sh/python-build-standalone`, release `20260825`, `install_only_stripped` Windows MSVC archive;
- Python archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` from PyPI;
- OCRmyPDF wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

The normal `pip` Windows console launcher is deliberately not trusted for portability because it may capture the interpreter path used during installation. PDF_Tunner removes that generated OCRmyPDF launcher and builds a tiny native `tools/python/ocrmypdf.exe` shim that resolves the sibling `python.exe` and executes `python.exe -m ocrmypdf`. The shim also directs OCRmyPDF temporary state to `data/tmp/ocrmypdf/` and Python bytecode cache to `data/python-cache/`.

A focused candidate workflow, `.github/workflows/pdf-tunner-ocrmypdf-candidate.yml`, tests the package before it is integrated into the heavy primary workflow. It stages the already accepted Ghostscript and Tesseract prerequisites, then requires:

- pinned Python archive hash and exact Python version;
- pinned OCRmyPDF wheel hash and exact OCRmyPDF version;
- AMD64 Python and launcher executables;
- isolated `where` resolution for `python`, `ocrmypdf`, `gs` and `tesseract` entirely inside the synthetic portable tree;
- `pip check` consistency;
- a real image -> searchable PDF OCR operation;
- extraction of the expected searchable text layer;
- package-local OCRmyPDF temp/Python cache;
- a second full OCR run after copying the portable tree to a different path containing spaces.

Focused Run `33165240128` (#1), job `98828956888`, is diagnostic failure evidence only. Python 3.12.14 and OCRmyPDF 17.10.0 staged successfully, the pinned Python archive and OCRmyPDF wheel hashes matched, and `pip check` reported no broken requirements. The run failed before the real OCR operation because `pip freeze` represented the locally installed verified wheel as a temporary `file://` origin instead of the validator's required `ocrmypdf==17.10.0`. The package inventory now uses `pip list --format=freeze`, which records installed packages canonically as `name==version` independent of installation origin.

This focused workflow is **diagnostic/candidate evidence only**. OCRmyPDF becomes accepted only after the same layer is integrated into `.github/workflows/pdf-tunner-windows-portable.yml` and the complete primary workflow passes with the real PDF_Tunner backend accepting `ocrmypdf`.

## Architecture

PDF_Tunner uses Stirling's own Tauri desktop app in `frontend/editor/src-tauri`. The old `PDF_Tunner_Legacy` .NET/WebView2 launcher is reference material only.

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`. PDF_Tunner does not globally replace Windows profile variables before Tauri/WebView2 initialization. Instead it localizes state component by component:

- Stirling backend config/logs/working state -> `data/`;
- Java temp -> `data/tmp/`;
- WebView2 profile -> `data/webview2/`;
- Tauri logs/store/cookies/window state -> `data/tauri/...`;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- Tesseract models -> `tools/tesseract/tessdata/` through `TESSDATA_PREFIX`;
- OCRmyPDF temp -> `data/tmp/ocrmypdf/`;
- Python cache -> `data/python-cache/`;
- Calibre config -> `data/calibre/` when Calibre is added.

Portable mode also skips runtime `pdf-tunner://` protocol registration. The primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

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

During active development it has one branch-scoped `push` trigger plus `workflow_dispatch`, with `concurrency` and `cancel-in-progress: true`. Development-only push/status mechanisms must be removed before final integration to `main`.

A dependency is accepted only when the **complete current primary workflow** is green. `--version` alone is never sufficient: where practical the CI must execute a real operation with isolated PATH/environment proving that a runner-installed tool is not satisfying the test.

## Remaining v1 roadmap

1. Finish OCRmyPDF candidate, integrate it into the primary workflow and obtain complete acceptance.
2. Complete external toolchain: LibreOffice; UNO/Unoconvert; Poppler (`pdftohtml`, `pdfinfo`, `pdfimages`); portable Python consolidation; NumPy; OpenCV; WeasyPrint; Calibre; `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate `jbig2enc`; establish viable RAR/CBR support or document the concrete limitation; add any further dependency found in exact pinned source.
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
