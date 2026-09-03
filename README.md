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
- Latest complete green primary regression: **Run #96** (`33748509811`), job `100626447125`, functional commit `0874881eaadcede5095e3db0052ce8b78cc23906`.
- **Calibre 9.14.0 / `ebook-convert` is formally accepted by Run #96.**
- Active external-toolchain candidate: **unpaper 6.1 + pngquant 3.0.3**, integrated as OCRmyPDF 17.10.0 auxiliary tools. They are not accepted until the complete primary workflow is green with all previous gates enabled.
- Run #97 (`33753982510`), job `100643848626`, commit `f2259ad2456dcba4c03ec0a7d2bbb19e1422c05d`, failed during `Stage portable Python, OCRmyPDF and NumPy` after the accepted core had already populated the portable Python runtime. The failure is therefore inside the new auxiliary invocation path, not a reopening of the accepted Python/OCRmyPDF core.

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
| Poppler | `26.02.0` Windows x64: `pdftohtml`, `pdfinfo`, `pdfimages`; Run #86 `33507551477` |
| Python dependency lock | authenticated 28-package Windows lock; Run #87 and later complete regressions |
| NumPy | `2.5.2`; Run #90 `33530454097` |
| OpenCV | `opencv-python-headless 4.14.0.94`, runtime/core `4.14.0`, real `split_photos.py`; Run #92 `33557169326` |
| WeasyPrint | official Windows `69.0`, package-relative shim, real HTML→PDF + Markdown→PDF; Run #95 `33695530172` |
| **Calibre** | official Windows x64 `9.14.0`, package-relative `ebook-convert` launcher, real PDF↔eBook routes; **Run #96 `33748509811`** |

## Recent acceptance evidence

### WeasyPrint 69.0 — accepted

Pinned Stirling 2.14.3 resolves literal `weasyprint`, requires version `58.0` or newer and executes `weasyprint -e utf-8 -v --pdf-forms INPUT OUTPUT`. PDF_Tunner pins the official Kozea WeasyPrint `69.0` Windows archive, SHA-256 `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`.

Complete primary Run #95 (`33695530172`), job `100463449110`, commit `a7a118e852277069c8ab13cc2f25121f9be87fea`, passed isolated package-only validation, real HTML→PDF, relocation with spaces, live Stirling HTML→PDF + Markdown→PDF, all prior dependency gates, portable state/process cleanup, final layout and ZIP generation. Run #95 ZIP SHA-256: `CFD09D41CC5E074B7CEF1885F5A32ED58F08E2FE6FB9EEBC0C0AA07B2A16C0FE`.

### Calibre 9.14.0 / `ebook-convert` — accepted

Pinned Stirling 2.14.3 resolves literal `ebook-convert`. PDF→EPUB uses Calibre with `--pdf-engine pdftohtml`, so the accepted package deliberately reuses the already accepted package-local Poppler. eBook→PDF accepts the formats exposed by Stirling and can subsequently use Ghostscript optimization.

PDF_Tunner packages the official Calibre Windows x64 MSI `calibre-64bit-9.14.0.msi`, URL `https://download.calibre-ebook.com/9.14.0/calibre-64bit-9.14.0.msi`, SHA-256 `4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d`. CI performs MSI administrative extraction only; Calibre is never installed on the runner.

`tools/bin/ebook-convert.exe` is a native package-relative launcher for `tools/calibre/ebook-convert.exe`. It keeps config/cache under `data/calibre/`, per-invocation temp under `data/tmp/calibre/`, sets `CALIBRE_NO_DEFAULT_PROGRAMS=1`, and cleans invocation temp after exit.

**Complete primary Run #96 (`33748509811`), job `100626447125`, commit `0874881eaadcede5095e3db0052ce8b78cc23906`, passed every primary step and formally accepts Calibre 9.14.0.** It passed authenticated MSI extraction, AMD64/package-first validation, direct conversions, relocation with spaces, both real Stirling eBook routes, all previously accepted dependency gates, backend startup, portable containment, final layout and ZIP generation.

Run #96 evidence:

- ZIP: `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`
- ZIP size: `1,837,322,506` bytes
- ZIP SHA-256: `724C882195965A9F5676ADB6B4ED09FE1ED32EED09D74424D76DEF7B59C7CCAE`
- portable layout: `31,400` files / `4,228,817,694` payload bytes
- Calibre backend `ebook-convert.exe` SHA-256: `4e786948f256e7d7b944540f6f131a2b77d6f6be515edb8987158496815754c1`
- Calibre launcher SHA-256: `b6392ee2e1357f25e469eade1914a6162aecdabde52122fdd8192b3c48e3ffcd`
- retained lightweight artifact: `9891758584`, `7,273` bytes, Actions digest `sha256:d03923535d0b2d9e61aa4ea7ed3f82e84ae241d8380abd4a62d77b2874431bf7`, expires 2026-09-10
- the multi-gigabyte ZIP itself was **not uploaded**, by design.

## Active candidate — OCRmyPDF auxiliaries

Pinned Stirling 2.14.3 installs `unpaper` and `pngquant` in its standard runtime image, but does not expose them as independent dependency groups. Their relevant behavior comes through the already accepted OCRmyPDF `17.10.0` runtime:

- `unpaper` is the external tool used by OCRmyPDF for `--clean` and `--clean-final`; Stirling's `/ocr-pdf` controller exposes both options.
- `pngquant` is the external quantizer used by OCRmyPDF optimization levels 2 and 3.
- OCRmyPDF 17.10.0 probes literal commands `unpaper` and `pngquant` on `PATH`; there is no OCRmyPDF minimum-version gate for either tool.

Candidate payloads:

- **unpaper 6.1 Windows x86_64 community build** from `rodrigost23/unpaper`, archive `unpaper-6.1-windows-x86_64.zip`, SHA-256 `a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65`. The current upstream release is 7.0.0 but its official release publishes source only, not a Windows binary; this exception is therefore explicit rather than misrepresented as an official binary.
- **pngquant 3.0.3 official Windows archive** from `https://pngquant.org/pngquant-windows.zip`, SHA-256 `bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d`.

Both are staged under `tools/bin/`, which the portable bootstrap already places before host PATH. unpaper's required sibling DLLs remain beside `unpaper.exe`.

Candidate validation requires:

1. exact archive hashes and provenance;
2. AMD64 PE identity;
3. isolated package-first `where.exe` resolution;
4. exact version probes;
5. OCRmyPDF 17.10.0 `ToolProbe` recognition;
6. execution through OCRmyPDF's actual `unpaper.run_unpaper` and `pngquant.quantize` wrappers;
7. real OCRmyPDF `--clean --clean-final` processing;
8. relocation to a path containing spaces;
9. all previously accepted primary gates, final layout and lightweight evidence.

To reduce regression risk, the previously accepted `.github/scripts/prepare-ocrmypdf.ps1` implementation is preserved byte-for-byte as `.github/scripts/prepare-ocrmypdf-core.ps1`. The existing workflow entry path remains `.github/scripts/prepare-ocrmypdf.ps1`, now a narrow wrapper that executes the accepted core and then `.github/scripts/prepare-ocr-aux.ps1`.

### Run #97 — failed candidate and bounded diagnostic correction

Run #97 (`33753982510`), job `100643848626`, commit `f2259ad2456dcba4c03ec0a7d2bbb19e1422c05d`, failed in the combined Python/OCRmyPDF staging step. Its bounded artifact `9893464267` proved that the accepted Python/OCRmyPDF core had already populated the portable runtime and generated Python cache entries, including OCRmyPDF's `unpaper` and `pngquant` modules. The artifact did **not** retain the exception text emitted by the newly invoked auxiliary script, so #97 does not identify a defensible line-level root cause and does not accept the candidate.

The next diagnostic revision keeps the accepted core untouched and changes only the narrow wrapper. Immediately before invoking `.github/scripts/prepare-ocr-aux.ps1`, it creates `data/logs/ocr-aux-diagnostic.log`; on failure it records exception type/message, fully-qualified error ID, category, script/line/offset, source line, position message, PowerShell script stack trace and the formatted error record, then rethrows the original failure. The existing bounded startup-diagnostics collector already retains package-local `.log` tails, so no large artifact or extra workflow is required. On a green run the temporary diagnostic log is removed by the existing final `data/` cleanup and is not shipped in the portable ZIP.

## Portable architecture

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`. State is localized component by component rather than by globally replacing user-profile variables before Tauri/WebView2 initialization.

Key paths:

- backend config/logs/working state → `data/`
- Java temp → `data/tmp/`
- WebView2 profile → `data/webview2/`
- Tauri logs/store/cookies/window state → `data/tauri/...`
- ImageMagick → `tools/imagemagick/`, temp → `data/tmp/imagemagick/`
- Tesseract → `tools/tesseract/`, models → `tools/tesseract/tessdata/`
- Python/OCRmyPDF/NumPy/OpenCV → `tools/python/`; OCRmyPDF temp → `data/tmp/ocrmypdf/`; Python cache → `data/python-cache/`
- LibreOffice → `tools/libreoffice/`; `unoconvert.exe` → `tools/bin/`
- Poppler → `tools/poppler/Library/bin/`
- WeasyPrint → `tools/weasyprint/`; literal shim → `tools/bin/weasyprint.exe`; temp → `data/tmp/weasyprint/`
- Calibre → `tools/calibre/`; literal launcher → `tools/bin/ebook-convert.exe`; state → `data/calibre/`; temp → `data/tmp/calibre/`
- OCRmyPDF auxiliaries → `tools/bin/unpaper.exe` + required DLLs and `tools/bin/pngquant.exe`

Portable mode skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## Validation and CI policy

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. Version output alone is never sufficient: validate authenticated source/hash, package-first isolation, real operation, relocation where practical, backend behavior where applicable, state/process containment and the final assembled package.

Heavy CI uses branch-scoped concurrency with `cancel-in-progress: true`. Do not launch redundant complete regressions.

Ordinary CI always builds and validates the portable ZIP but uploads only lightweight evidence. Do not upload the multi-gigabyte portable ZIP, dependency archives, wheelhouses or caches during ordinary iterations. Final ZIP publication is a GitHub Release action only after all v1 gates pass and the user explicitly authorizes release.

## Remaining v1 roadmap

### A. External toolchain

1. **unpaper 6.1 + pngquant 3.0.3** — active OCRmyPDF auxiliary candidate; complete primary regression is the acceptance gate;
2. conversion fonts required by pinned Stirling functionality;
3. explicit VeraPDF E2E;
4. investigate/build/package `jbig2enc` if technically viable;
5. viable portable RAR/CBR support or a concrete documented limitation;
6. any further exact dependency exposed by the pinned-source parity audit.

### B. Functional validation

Representative E2E must cover OCR, Office↔PDF, HTML/URL/base-URL/EML paths, accepted WeasyPrint, accepted Poppler, accepted Calibre/eBook conversion, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF regressions, `unpaper`/`pngquant`, and RAR/CBR or jbig2enc if integrated. Tests must prove that runner-preinstalled software is not satisfying package gates.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove retired focused/diagnostic/integration mechanisms;
5. final downstream diff and output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish the clean v1 ZIP only when all gates are complete and explicitly authorized;
9. manual clean-machine Windows 10/11 checklist.

## Compact changelog / handoff

- 2026-08-21–27: real fork/Tauri architecture established; portable state containment, WebView2, qpdf, ImageMagick, Ghostscript and Tesseract accepted.
- 2026-08-28: Python 3.12.14 + OCRmyPDF 17.10.0 accepted by Run #77.
- 2026-09-01: LibreOffice/unoconvert accepted by #83; Poppler by #86; authenticated Python lock and NumPy by #87/#90; OpenCV by #92.
- 2026-09-03: WeasyPrint 69.0 formally accepted by complete primary Run #95.
- **2026-09-03: Calibre 9.14.0 formally accepted by complete primary Run #96 (`33748509811`), job `100626447125`, commit `0874881eaadcede5095e3db0052ce8b78cc23906`.**
- **2026-09-03: Run #97 (`33753982510`) failed inside the new unpaper/pngquant auxiliary staging path after the accepted Python/OCRmyPDF core completed. Its bounded artifact lacked the actual exception text, so the candidate remains unaccepted.**
- **Current:** the wrapper now captures a bounded package-local `ocr-aux-diagnostic.log` before rethrowing any auxiliary failure; the next complete primary run will either expose the exact line-level root cause or, if green, become the acceptance gate for unpaper 6.1 + pngquant 3.0.3.