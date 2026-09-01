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
- OCRmyPDF `17.10.0` with a package-relative native launcher;
- LibreOffice `26.2.5` with package-relative native `unoconvert.exe`.

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

### LibreOffice 26.2.5 + native `unoconvert` — accepted

The complete primary regression is green, including the real backend routes. LibreOffice and the native `unoconvert` compatibility shim are formally accepted on the evidence of primary Run #83. The integration pins the official The Document Foundation Windows x86-64 MSI:

- LibreOffice `26.2.5`;
- source: `https://download.documentfoundation.org/libreoffice/stable/26.2.5/win/x86_64/LibreOffice_26.2.5_Win_x86-64.msi`;
- MSI SHA-256 `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`.

CI performs MSI **administrative extraction only**; it never installs LibreOffice on the runner. The resulting payload is `tools/libreoffice/`, including `program/soffice.com` and `program/soffice.exe`. It builds `tools/bin/unoconvert.exe` from `.github/scripts/unoconvert-launcher.rs`: a native, package-relative compatibility shim which invokes bundled `soffice.com` (with `soffice.exe` fallback), creates a unique temporary LibreOffice profile under `p/`, localizes child `TEMP`/`TMP` to `data/tmp/libreoffice/`, and cleans the profile after every operation.

The shim intentionally does **not** run `unoserver`. It accepts Stirling's `--convert-to` and `--input-filter` split/equal forms, safely ignores the injected UNO endpoint metadata (`--host`, `--port`, `--host-location`, `--protocol` in both forms), translates the input filter to `--infilter`, and moves LibreOffice's output to Stirling's exact requested output path.

The primary gate stages provenance and hashes, proves `where soffice` and `where unoconvert` resolve only inside the package with `tools/bin` first, runs direct `soffice` DOCX -> PDF plus shim DOCX -> PDF and PDF -> DOCX (`writer_pdf_import`), moves an already-used full portable tree between ordinary Windows paths containing spaces, and checks package-local temp/profile cleanup and no bundled LibreOffice process remains. It then starts the actual Tauri/Stirling backend with a package-only inherited `PATH`, verifies that `ExternalAppDepConfig` has not disabled either LibreOffice or Unoconvert, and exercises `/api/v1/convert/file/pdf` and `/api/v1/convert/pdf/word`.

Focused candidate Run #13 (`33272788391`, job `99154179041`, commit `8dea43f511771f5483f6b038067cfd39ec7f68e3`) validated the isolated payload/shim design only. Complete primary Run #83 (`33497784837`), job `99823839704`, commit `355c0cf5cfe7afaadd89933a0aa3fb13456ebb83`, passed every prior gate plus direct/shim DOCX→PDF and PDF→DOCX, normal relocation with spaces, package-local cleanup, and real Stirling Office→PDF/PDF→DOCX backend routes. It generated ZIP SHA-256 `1F0D6AE03FD5F0A6158128669517E5378CADE9B1BE358DE0272600ED9126D105`; retained evidence artifact `9797397461` is 957 bytes, digest `sha256:9a3ac1af4d03dcae8b69cda20fc5f2f824c5486a7112991f112addd2fc9cdb12`, expiring 2026-09-08. LibreOffice is known to be sensitive to unusually extreme Windows path lengths; v1 acceptance requires normal relocation and spaces, not artificially extreme paths.

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
- LibreOffice -> `tools/libreoffice/`; `unoconvert.exe` -> `tools/bin/`;
- LibreOffice child temp -> `data/tmp/libreoffice/`; transient shim profiles -> `p/`;
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

## CI artifact storage policy

The primary workflow always builds the portable ZIP and verifies its layout, functional gates, size and SHA-256. Ordinary CI retains only a small evidence artifact containing the package hash, size, provenance and layout summary; it does not upload the multi-gigabyte ZIP itself. Failure diagnostics are text-only, capped at 2 MB and retained for 3 days.

This preserves full regression coverage without consuming GitHub Actions storage for every iteration. Large ZIP retention is exceptional and must be justified before upload. The final user-deliverable ZIP will be attached to the GitHub Release only after the complete v1 acceptance process; no Release exists yet.

## Remaining v1 roadmap

1. Poppler (`pdftohtml`, `pdfinfo`, `pdfimages`).
2. Consolidate portable Python dependency lock; NumPy; OpenCV; WeasyPrint.
3. Calibre/`ebook-convert`; `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate `jbig2enc`; establish viable RAR/CBR support or document the limitation; add any further dependency found in exact pinned source.
4. Representative E2E operations across OCR, Office, HTML/URL -> PDF, Poppler, WeasyPrint, Calibre/EPUB, Python/OpenCV and representative Stirling API families.
5. Non-Enterprise parity audit against Stirling 2.14.3.
6. Final branding and portability audits.
7. CI/repository cleanup, including physical removal of the retired OCRmyPDF candidate workflow, and downstream diff hygiene review.
8. Final docs/provenance/version/hash record.
9. Integrate to `main` without reopening old PR #1.
10. Publish the clean v1 portable ZIP only after all gates, then perform the manual clean-machine Windows 10/11 checklist.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**
