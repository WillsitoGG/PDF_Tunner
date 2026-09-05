# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**, extract and run without installation.
- `main` remains the clean pinned upstream base during v1 development.
- No final PDF_Tunner v1 Release exists yet.
- Latest complete green primary regression: **Run #105** (`33956010668`), successful rerun job `101283384499`, commit `e2c2e0544bbd0f092980386b0e764550146c799e`.
- **Embedded VeraPDF 1.30.2 E2E is formally accepted by Run #105.**
- Active candidate: **jbig2enc 0.32** for OCRmyPDF optimization levels 2/3, built package-locally from the exact upstream tag/commit with static MSVC runtime and authenticated Meson fallbacks.
- Next after jbig2enc: finish the RAR/CBR portability decision, then the remaining pinned-source parity and representative functional E2E audits.

## Accepted portable layers

| Layer | Accepted identity / evidence |
| --- | --- |
| Native Tauri/JRE portable bootstrap | package-local backend/Tauri/WebView2/temp state and process containment; consolidated proof includes Run `32825188381` |
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
| Conversion fonts | LibreOffice MSI Latin baseline + pinned Noto Sans CJK `Sans2.004` Regular regional subsets; Run #103 `33896293861` |
| **Embedded VeraPDF** | **`validation-model:1.30.2`; real PDF→PDF/A-2b→`verify-pdf`; Run #105 `33956010668`** |

Pinned conversion-font hashes retained from the accepted Run #103 layer:

| Family | File | SHA-256 |
| --- | --- | --- |
| Noto Sans SC | `NotoSansSC-Regular.otf` | `faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9` |
| Noto Sans TC | `NotoSansTC-Regular.otf` | `5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537` |
| Noto Sans HK | `NotoSansHK-Regular.otf` | `8a43afea92bb58dfd9027bd7ac6f5b0b2662e2ffb3e7c1edc02c62b2b21924f1` |
| Noto Sans JP | `NotoSansJP-Regular.otf` | `dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073` |
| Noto Sans KR | `NotoSansKR-Regular.otf` | `69975a0ac8472717870aefeab0a4d52739308d90856b9955313b2ad5e0148d68` |

## Latest acceptance — embedded VeraPDF 1.30.2

VeraPDF is embedded in Stirling's Java application rather than shipped as a separate executable. The pinned core declares `org.verapdf:validation-model:1.30.2`, and the desktop JRE includes `jdk.dynalink`, which Stirling requires for VeraPDF runtime operation.

Run #104 (`33908989039`) correctly reached the new E2E after primary steps 1–34 but exposed a test-fixture problem: upstream `test_globalsign.pdf` is actually an HTML GlobalSign 404 page. The bounded diagnostics proved VeraPDF itself had already initialized successfully. Commit `e2c2e0544bbd0f092980386b0e764550146c799e` made only the justified correction: construct a deterministic valid PDF fixture at runtime while retaining the real PDF→PDF/A-2b→VeraPDF verification chain.

Run #105 attempt 1 then failed earlier at OCR auxiliary staging because `pngquant.org:443` timed out (`HttpRequestException` / socket `10060`). No code gate failed. A single rerun of the same job/commit succeeded completely, with all primary steps 1–44 green. The live backend gate reported:

- `VeraPDF Greenfield initialized successfully`;
- PDF/A result `standard=PDF_A_2_B`, profile `2B`, `compliant=True`, `totalFailures=0`;
- `Verification complete for 1 standard(s) checked`.

Run #105 acceptance evidence:

- run `33956010668`, attempt `2`, successful job `101283384499`, commit `e2c2e0544bbd0f092980386b0e764550146c799e`;
- ZIP name `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`;
- ZIP size `1,909,712,277` bytes;
- ZIP SHA-256 `5A3F30A60E014C12D5059C81A6DC7EC8789DB9F4D3D3F5DB1A4D1A7403CEC5FE`;
- portable layout `31,611` files / `4,387,634,583` payload bytes;
- lightweight evidence artifact `9967243279`, size `7,585` bytes, digest `sha256:cd87e3b3ebe282c47e06c018b4c6c602611bd372701d36fb321249e34586d24c`;
- attempt-1 diagnostic artifact `9966708360`, size `11,849` bytes, digest `sha256:8a611d843f4b436f87a4c81c0f9795a112b49135b3e2e4e4fc4ae584d09e8579`;
- the multi-gigabyte ZIP itself was not uploaded.

VeraPDF is closed/accepted; do not reopen it without new evidence.

## Active candidate — jbig2enc 0.32

OCRmyPDF `17.10.0` probes the literal executable name `jbig2`, and its Windows code explicitly warns that TeX Live may place an incompatible `jbig2.EXE` on host `PATH`. Optimize levels 2/3 recommend `jbig2enc >= 0.28`. Run #105 backend logs still reported the missing `jbig2` dependency, so this is a concrete remaining parity/compression gap rather than speculative tooling.

The candidate uses:

- upstream repository `agl/jbig2enc`;
- exact tag `0.32` → commit `309b2d55c7dfdcf0ab6afccb6d88834afc0bf2c0`;
- pinned Meson `1.10.0` wheel SHA-256 `4b27aafce281e652dcb437b28007457411245d975c48b5db3a797d3e93ae1585`;
- MSVC x64 release build with `b_vscrt=mt`, `default_library=static` and `--wrap-mode=forcefallback`;
- upstream authenticated Meson wrap hashes for Leptonica/codecs, with Meson's installed license closure retained;
- package path `tools/jbig2enc/`, which the existing portable Tauri bootstrap already places ahead of host `PATH`.

The acceptance gate in `.github/scripts/prepare-jbig2enc.ps1` must prove all of the following in the assembled portable tree:

1. exact upstream tag and commit;
2. authenticated Meson source/patch hashes for every wrap dependency;
3. upstream Meson tests pass under the pinned source build;
4. `jbig2.exe` is AMD64 and runs with an isolated PATH containing no Python, Visual Studio, MSYS2 or host tool directory;
5. `where.exe jbig2` resolves only the package copy;
6. OCRmyPDF's own `jbig2enc` ToolProbe sees version `0.32`;
7. real `ocrmypdf --optimize 2` on a deterministic bilevel fixture produces a PDF containing `/JBIG2Decode`;
8. the same binary remains detectable after relocation to a path containing spaces;
9. provenance, packaged-file SHA-256 values, Apache-2.0 notice, patent notice and Meson-installed dependency licenses remain inside `tools/jbig2enc/`.

The official 0.32 release does publish a Windows X64 MSVC ZIP, but its upstream Windows workflow builds in debug mode. PDF_Tunner therefore builds the exact tagged source itself so the portable artifact can explicitly force a release build and static MSVC CRT instead of inheriting a potentially host-dependent debug runtime.

## RAR / CBR portability finding

Pinned Stirling 2.14.3 has asymmetric CBR behavior:

- **CBR→PDF** is implemented through embedded Java `junrar`, so that direction does not need an external `rar.exe`.
- **PDF→CBR** invokes the real RAR CLI (`rar a -m5 -ep1`). A ZIP renamed to `.cbr` would not be equivalent and is not an acceptable parity workaround.

The RAR/WinRAR redistribution terms do not provide a clean basis to bundle the standalone encoder inside PDF_Tunner without permission. The current v1 direction is therefore to preserve CBR→PDF as fully portable and, for PDF→CBR, support a user-supplied/licensed `rar.exe` at the existing package-first `tools/rar/` path. This will be finalized after jbig2enc rather than silently dropping or faking the feature.

## Portable architecture

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside the executable.

Key package-relative paths:

- backend config/logs/working state → `data/`;
- Java temp → `data/tmp/`;
- WebView2 profile → `data/webview2/`;
- Tauri logs/store/cookies/window state → `data/tauri/...`;
- ImageMagick → `tools/imagemagick/`;
- Ghostscript → `tools/ghostscript/bin/`;
- Tesseract → `tools/tesseract/`, models → `tools/tesseract/tessdata/`;
- Python/OCRmyPDF/NumPy/OpenCV → `tools/python/`;
- LibreOffice → `tools/libreoffice/`; `unoconvert.exe` → `tools/bin/`;
- conversion fonts → `tools/libreoffice/share/fonts/truetype/`; provenance → `tools/fonts/`;
- Poppler → `tools/poppler/Library/bin/`;
- WeasyPrint → `tools/weasyprint/`; shim → `tools/bin/weasyprint.exe`;
- Calibre → `tools/calibre/`; launcher → `tools/bin/ebook-convert.exe`;
- OCRmyPDF auxiliaries → `tools/bin/unpaper.exe`, sibling DLLs and `tools/bin/pngquant.exe`;
- jbig2enc candidate → `tools/jbig2enc/jbig2.exe`;
- optional licensed RAR encoder path → `tools/rar/`.

Portable mode skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## Validation and CI policy

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency or functional layer is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. Version output alone is never sufficient: validate source/hash or embedded identity, package-first isolation, real operation, relocation where practical, backend behavior where applicable, state/process containment and the final assembled package.

Heavy CI uses branch-scoped concurrency with `cancel-in-progress: true`. Do not launch redundant complete regressions. Ordinary CI builds and validates the portable ZIP but uploads only lightweight evidence; the multi-gigabyte ZIP itself is reserved for the final Release after all v1 gates and explicit user authorization.

## Remaining v1 roadmap

### A. External toolchain / embedded runtime parity

1. **jbig2enc 0.32** — active candidate;
2. finalize portable RAR/CBR behavior and validation;
3. finish exact dependency audit against pinned Stirling 2.14.3 and close any remaining concrete gap.

### B. Representative functional E2E

Cover OCR, Office↔PDF, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, VeraPDF, jbig2enc, RAR/CBR behavior and representative Stirling API families. Tests must prove runner-installed software is not satisfying package gates.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove retired diagnostic/focused mechanisms;
5. downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish the clean v1 ZIP only after all gates and explicit user authorization;
9. execute the manual clean-machine Windows 10/11 checklist.

## Compact handoff

- Latest complete green primary: **Run #105 `33956010668`**, attempt `2`, job `101283384499`, commit `e2c2e0544bbd0f092980386b0e764550146c799e`.
- Newly accepted: **embedded VeraPDF 1.30.2 E2E**.
- Run #105 ZIP SHA-256 `5A3F30A60E014C12D5059C81A6DC7EC8789DB9F4D3D3F5DB1A4D1A7403CEC5FE`; size `1,909,712,277`; layout `31,611` files / `4,387,634,583` bytes; lightweight artifact `9967243279`, digest `sha256:cd87e3b3ebe282c47e06c018b4c6c602611bd372701d36fb321249e34586d24c`.
- Active candidate: **jbig2enc 0.32**, exact commit `309b2d55c7dfdcf0ab6afccb6d88834afc0bf2c0`, source-built with static MSVC CRT and force-fallback authenticated dependencies.
- Next: finalize RAR/CBR, then complete parity/E2E/release-readiness audits.
- No final Release has been published.
