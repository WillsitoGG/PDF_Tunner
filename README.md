# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**, extract and run without installation.
- `main` remains the clean pinned upstream base during v1 development.
- No final PDF_Tunner v1 Release exists yet.
- Latest complete green primary regression: **Run #103** (`33896293861`), job `101099606785`, commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f`.
- **Package-local conversion fonts are formally accepted by Run #103.**
- Active candidate: **embedded VeraPDF 1.30.2 E2E**, using the real portable backend rather than adding another external executable.

## Accepted portable layers

| Layer | Accepted identity / evidence |
| --- | --- |
| Native Tauri/JRE portable bootstrap | package-local backend/Tauri/WebView2/temp state and process containment; consolidated state proof includes Run `32825188381` |
| Fixed WebView2 | `151.0.4129.101` x64; Run #62 `33058462619` |
| qpdf | `12.4.0` MinGW64; Run #66 `33086404875` |
| ImageMagick | `7.1.2-30` portable Q16 x64; Run #67 `33092698357` |
| Ghostscript | `10.07.1` Win64; Run #68 `33104114920` |
| Tesseract | release `5.5.3`, CLI `5.5.3.20260724`, pinned `eng`/`spa`/`osd`; Run #70 `33122172947` |
| Python + OCRmyPDF | Python `3.12.14` x64 + OCRmyPDF `17.10.0`; Run #77 `33201568275` |
| LibreOffice + UNO conversion | LibreOffice `26.2.5` + package-relative native `unoconvert.exe`; Run #83 `33497784837` |
| Poppler | `26.02.0` Windows x64; Run #86 `33507551477` |
| Python dependency lock | authenticated 28-package Windows lock; Run #87 and later complete regressions |
| NumPy | `2.5.2`; Run #90 `33530454097` |
| OpenCV | `opencv-python-headless 4.14.0.94`, runtime/core `4.14.0`, real `split_photos.py`; Run #92 `33557169326` |
| WeasyPrint | official Windows `69.0`, package-relative shim, real HTML→PDF + Markdown→PDF; Run #95 `33695530172` |
| Calibre | official Windows x64 `9.14.0`, package-relative `ebook-convert`; Run #96 `33748509811` |
| OCRmyPDF auxiliaries | unpaper `6.1` + pngquant `2.17.0`; Run #99 `33786563784` |
| **Conversion fonts** | LibreOffice MSI Latin baseline + pinned Noto Sans CJK `Sans2.004` Regular regional subsets; **Run #103 `33896293861`** |

## Previously accepted milestone — unpaper 6.1 + pngquant 2.17.0

Complete primary Run #99 (`33786563784`), job `100752651171`, commit `8d4d3906f6535c5a0e214cf96948e19de0678a23`, passed every primary step and formally accepted:

- unpaper `6.1` Windows x86_64 community build, archive SHA-256 `a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65`;
- pngquant `2.17.0` official pngquant.org Windows archive, SHA-256 `bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d`.

Run #99 ZIP evidence: size `1,861,405,214` bytes, SHA-256 `5AFD552CFDF4DCEF48151470154541694AAFC5E1DD6650E913D2BDBD6D51496F`, layout `31,468` files / `4,303,215,732` payload bytes. The multi-gigabyte ZIP was not uploaded.

## Latest acceptance — package-local conversion fonts

Pinned Stirling 2.14.3 installs DejaVu, Liberation, Carlito/Caladea, Noto and Noto CJK fonts in its Linux runtime. For Windows, the authenticated official LibreOffice 26.2.5 MSI contains the important Latin/Office baseline as a separate MSI `Fonts` payload because a normal installation targets the Windows font store.

Runs #100 and #101 failed at primary step 32 without enough detail. Run #102 (`33861701712`), job `100987374348`, commit `05c5121e197fd43a25b70d8c25ceed3d1141357d`, retained bounded phase evidence proving `CORE_SUCCESS` followed by `FONTS_FAILURE`: `tools/libreoffice/share/fonts/truetype` did not exist after the administrative extraction.

The correction in commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f` preserves the same authenticated MSI `Fonts` payload under `tools/libreoffice/share/fonts/truetype` while keeping the LibreOffice URL/SHA, launcher strategy and all validation gates unchanged. It then adds only the five pinned Noto Sans CJK `Sans2.004` Regular regional subsets:

| Family | File | SHA-256 |
| --- | --- | --- |
| Noto Sans SC | `NotoSansSC-Regular.otf` | `faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9` |
| Noto Sans TC | `NotoSansTC-Regular.otf` | `5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537` |
| Noto Sans HK | `NotoSansHK-Regular.otf` | `8a43afea92bb58dfd9027bd7ac6f5b0b2662e2ffb3e7c1edc02c62b2b21924f1` |
| Noto Sans JP | `NotoSansJP-Regular.otf` | `dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073` |
| Noto Sans KR | `NotoSansKR-Regular.otf` | `69975a0ac8472717870aefeab0a4d52739308d90856b9955313b2ad5e0148d68` |

**Complete Run #103 passed every primary step**, including direct LibreOffice DOCX→PDF, Poppler font/text proof, relocation, the real Stirling Office→PDF route, startup/containment, final layout and ZIP creation. This formally accepts conversion fonts.

Run #103 evidence:

- run `33896293861`, job `101099606785`, commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f`;
- ZIP name `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`;
- ZIP size `1,909,704,241` bytes;
- ZIP SHA-256 `26F9CE12AB4A949F0FB0BBEE503F630AFF7D457D2EBB6AB990E57DC78B57FE00`;
- portable layout `31,611` files / `4,387,634,585` payload bytes;
- lightweight artifact `9947175939`, size `7,580` bytes, digest `sha256:4ab2522e4baa8a3de6fcbe421191a31f81274d3940112e8c7d7785e8be19c963`;
- the multi-gigabyte ZIP itself was not uploaded.

## Active candidate — embedded VeraPDF 1.30.2 E2E

VeraPDF is **not an external executable dependency** in this Stirling base. `app/core/build.gradle` embeds `org.verapdf:validation-model:1.30.2` in the application, and the desktop JRE explicitly includes `jdk.dynalink`, required by VeraPDF at runtime.

The candidate adds `.github/scripts/validate-verapdf.ps1` and invokes it only during the existing live-backend validation path. The gate must:

1. confirm the pinned source still declares `validation-model:1.30.2`;
2. prove the bundled JRE exposes `jdk.dynalink`;
3. use the real portable backend with its package-first PATH;
4. convert `test_globalsign.pdf` through `/api/v1/convert/pdf/pdfa` to `pdfa-2b`;
5. submit that generated PDF/A to `/api/v1/security/verify-pdf`;
6. require a declared PDF/A result, `compliant=true`, zero failures and PDF/A-2b identity;
7. require backend logs to prove `VeraPDF Greenfield initialized successfully` and completion of the real verification controller;
8. preserve every previously accepted gate, final cleanup and lightweight artifact policy.

No additional VeraPDF binary, runtime download or package payload is added to the portable ZIP.

**Do not call VeraPDF E2E accepted until one complete primary workflow is green with this gate enabled.**

## Portable architecture

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside the executable.

Key package-relative paths:

- backend config/logs/working state → `data/`;
- Java temp → `data/tmp/`;
- WebView2 profile → `data/webview2/`;
- Tauri logs/store/cookies/window state → `data/tauri/...`;
- ImageMagick → `tools/imagemagick/`;
- Tesseract → `tools/tesseract/`, models → `tools/tesseract/tessdata/`;
- Python/OCRmyPDF/NumPy/OpenCV → `tools/python/`;
- LibreOffice → `tools/libreoffice/`; `unoconvert.exe` → `tools/bin/`;
- conversion fonts → `tools/libreoffice/share/fonts/truetype/`; provenance → `tools/fonts/`;
- Poppler → `tools/poppler/Library/bin/`;
- WeasyPrint → `tools/weasyprint/`; shim → `tools/bin/weasyprint.exe`;
- Calibre → `tools/calibre/`; launcher → `tools/bin/ebook-convert.exe`;
- OCRmyPDF auxiliaries → `tools/bin/unpaper.exe` + sibling DLLs and `tools/bin/pngquant.exe`.

Portable mode skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## Validation and CI policy

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency or functional layer is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. Version output alone is never sufficient: validate source/hash or embedded identity, package-first isolation, real operation, relocation where practical, backend behavior where applicable, state/process containment and the final assembled package.

Heavy CI uses branch-scoped concurrency with `cancel-in-progress: true`. Do not launch redundant complete regressions. Ordinary CI builds and validates the portable ZIP but uploads only lightweight evidence; the multi-gigabyte ZIP itself is reserved for the final Release after all v1 gates and explicit user authorization.

## Remaining v1 roadmap

### A. External toolchain / embedded runtime parity

1. **embedded VeraPDF E2E** — active candidate;
2. investigate/build/package `jbig2enc` if technically viable;
3. viable portable RAR/CBR support or a concrete documented limitation;
4. any further exact dependency exposed by the pinned-source parity audit.

### B. Functional validation

Representative E2E must cover OCR, Office↔PDF, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, VeraPDF, and RAR/CBR or jbig2enc if integrated. Tests must prove runner-installed software is not satisfying package gates.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove retired diagnostic/integration mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish the clean v1 ZIP only when all gates are complete and explicitly authorized;
9. manual clean-machine Windows 10/11 checklist.

## Compact handoff

- Latest complete green primary: **Run #103 `33896293861`**, job `101099606785`, commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f`.
- Newly accepted: **package-local conversion fonts**.
- Run #103 ZIP SHA-256: `26F9CE12AB4A949F0FB0BBEE503F630AFF7D457D2EBB6AB990E57DC78B57FE00`; size `1,909,704,241`; layout `31,611` files / `4,387,634,585` bytes; lightweight artifact `9947175939` digest `sha256:4ab2522e4baa8a3de6fcbe421191a31f81274d3940112e8c7d7785e8be19c963`.
- Active candidate: **embedded VeraPDF 1.30.2 E2E**, no extra runtime payload; real PDF→PDF/A-2b→`verify-pdf` chain against the portable backend.
- Next after VeraPDF: **`jbig2enc` feasibility/integration**.
- No final Release has been published.
