# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository.

## Identity, base and target

PDF_Tunner is the real fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

- Pinned upstream version: `2.14.3`
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: Windows 10/11 x64 portable ZIP, extract and run without installation.
- Preserve Stirling non-Enterprise functionality unless explicitly removed.
- Bundle required runtimes/dependencies whenever technically viable.
- Keep runtime config/cache/log/temp/state inside the portable tree as far as underlying Windows APIs permit.
- Keep the downstream delta small and easy to rebase on Stirling upstream.
- `main` remains the clean pinned upstream base during v1 development.
- No final PDF_Tunner v1 Release exists yet.

## Mandatory repository rules

1. Preserve Stirling's root structure; do not reorganize the fork into generic archive/source roots.
2. Keep `main` clean: no generated builds, logs, abandoned experiments, one-shot triggers or temporary artifacts.
3. Preserve upstream behavior unless the user requests removal or functionality is outside target.
4. Compilation alone is never validation. Validate the assembled portable app and real operations.
5. Never archive failed/intermediate builds as release history.
6. Keep SHA-256/provenance and exact dependency identity reproducible.
7. **Every PDF_Tunner-specific change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
8. Heavy CI must use branch/workflow-specific concurrency with `cancel-in-progress: true`.
9. Use at most one automatic trigger per heavy workflow unless technically necessary.
10. Avoid redundant complete regressions; inspect failures and apply the smallest justified correction first.
11. Remove development-only focused/integration/diagnostic mechanisms before final `main` integration.
12. Do not reopen old PR #1 as the v1 release integration vehicle.
13. Do not publish a final Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete, and never without explicit user authorization.
14. Ordinary CI must never upload the multi-gigabyte portable ZIP; retain lightweight evidence only.

## Continuity protocol

Before writes in a resumed conversation:

1. recover the most recent PDF_Tunner handoff;
2. read the project `00.` rules plus current README and AGENTS;
3. verify live development-branch HEAD, latest primary Actions run, PR state and Release state;
4. carry accepted/closed, active candidate, next block and broader roadmap explicitly;
5. never treat one immediate dependency as the only remaining work;
6. at each accepted milestone record commit, Run/job, artifact/digest where relevant, next candidate and remaining roadmap in README + AGENTS;
7. before final Release re-audit against the full original PDF_Tunner objective.

## Architecture and portable boundary

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`. Do not restore the old `PDF_Tunner_Legacy` .NET/WebView2 launcher architecture.

Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable.

Do **not** globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before Tauri/WebView2 initializes. Use component-specific localization:

- `PDF_TUNNER_PORTABLE_ROOT` → executable directory;
- Stirling app data → `<portable>/data`;
- Java temp → `<portable>/data/tmp` through `JAVA_TOOL_OPTIONS`;
- WebView2 user data → `<portable>/data/webview2`;
- Tauri logs/store/window-state/http cookies → `<portable>/data/tauri/...`;
- ImageMagick → `<portable>/tools/imagemagick`, temp → `<portable>/data/tmp/imagemagick`;
- Ghostscript → package-first `<portable>/tools/ghostscript/bin`;
- Tesseract → package-first `<portable>/tools/tesseract`, `TESSDATA_PREFIX=<portable>/tools/tesseract/tessdata`;
- Python/OCRmyPDF/NumPy/OpenCV → `<portable>/tools/python`; OCRmyPDF child temp → `<portable>/data/tmp/ocrmypdf`; Python cache → `<portable>/data/python-cache`;
- LibreOffice → `<portable>/tools/libreoffice`; native source-compatible `unoconvert.exe` → `<portable>/tools/bin`;
- Poppler → `<portable>/tools/poppler`, executables under `Library/bin`;
- WeasyPrint → `<portable>/tools/weasyprint`; package-relative literal shim → `<portable>/tools/bin/weasyprint.exe`; temp → `<portable>/data/tmp/weasyprint`;
- Calibre → `<portable>/tools/calibre`; package-relative literal launcher → `<portable>/tools/bin/ebook-convert.exe`; config/cache → `<portable>/data/calibre`; temp → `<portable>/data/tmp/calibre`; set `CALIBRE_NO_DEFAULT_PROGRAMS=1`;
- OCRmyPDF auxiliaries → `<portable>/tools/bin/unpaper.exe` with required sibling DLLs and `<portable>/tools/bin/pngquant.exe`;
- skip `pdf-tunner://` deep-link registration in portable mode.

## External dependency source of truth

For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- controllers/services executing each feature;
- exact accepted third-party package source when a dependency is mediated through OCRmyPDF or another bundled runtime.

Direct runtime probes include:

| Feature | Probe |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` >=58 |
| Poppler HTML | `pdftohtml` |
| UNO conversion | `unoconvert` |
| qpdf | `qpdf` >=12 |
| Tesseract | `tesseract` |
| CBR/RAR | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |
| OCR cleaning | OCRmyPDF `ToolProbe('unpaper')` |
| OCR optimization | OCRmyPDF `ToolProbe('pngquant')` |

Also audit conversion fonts, VeraPDF E2E, `jbig2enc`, RAR/CBR and any additional exact dependency exposed by pinned source.

## Tool layout strategy

Package dependencies under deterministic `tools/` paths. Tauri prepends, when present, `tools/bin`, Python/Scripts, LibreOffice program, Tesseract, Ghostscript, qpdf, Poppler `Library/bin`, WeasyPrint backend, ImageMagick, Calibre and later accepted subtrees. If Windows executable naming differs from Stirling's literal probe, provide a deterministic package-local alias/shim only after proving the exact probe. Never count runner-installed software as package evidence.

## Accepted layers and evidence

| Layer | Acceptance evidence |
| --- | --- |
| Native portable/Tauri containment | consolidated AppData/window-state proof includes Run `32825188381` |
| Fixed WebView2 `151.0.4129.101` x64 | Run #62 `33058462619`, commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4` |
| qpdf `12.4.0` | Run #66 `33086404875`, commit `413994c9ea368b5144a26686afef6011eba8de59` |
| ImageMagick `7.1.2-30` | Run #67 `33092698357`, commit `d1801e8569a23a762035a39dc7295de0f19e6115` |
| Ghostscript `10.07.1` | Run #68 `33104114920`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004` |
| Tesseract `5.5.3` / CLI `5.5.3.20260724` | Run #70 `33122172947`, commit `52429eb7812e8615ee39aab695641d495798c1ba` |
| Python `3.12.14` + OCRmyPDF `17.10.0` | Run #77 `33201568275`, job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31` |
| LibreOffice `26.2.5` + native `unoconvert` | Run #83 `33497784837`, job `99823839704`, commit `355c0cf5cfe7afaadd89933a0aa3fb13456ebb83` |
| Poppler `26.02.0` | Run #86 `33507551477`, job `99855128441`, commit `1b2bfdc4e99d87aa899a0701291db496f740f7ab` |
| authenticated Python dependency lock + NumPy `2.5.2` | complete Run #90 `33530454097`, job `99931980241`, commit `c32fb84eb2c0f7b157ef3217c59e57eee20b895b` |
| OpenCV distribution `4.14.0.94` / runtime `4.14.0` | Run #92 `33557169326`, job `100020722841`, commit `c4c2b7f6e320840faf3d8c61967351b529875a50` |
| WeasyPrint `69.0` | Run #95 `33695530172`, job `100463449110`, functional commit `a7a118e852277069c8ab13cc2f25121f9be87fea` |
| **Calibre `9.14.0` / `ebook-convert`** | **Run #96 `33748509811`, job `100626447125`, commit `0874881eaadcede5095e3db0052ce8b78cc23906`** |

### Fixed provenance values that must not drift silently

- WebView2 CAB SHA-256: `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`
- qpdf archive SHA-256: `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`
- ImageMagick archive SHA-256: `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`
- Ghostscript installer SHA-256: `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`
- Tesseract installer SHA-256: `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`
- Python archive SHA-256: `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`
- OCRmyPDF wheel SHA-256: `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`
- accepted 28-package Python lock SHA-256: `ededb999049d81b85527f4d4aa679179e747669df300083d91bc2dd4e14e430f`
- NumPy wheel SHA-256: `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`
- OpenCV wheel SHA-256: `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`
- LibreOffice MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`
- Poppler archive SHA-256: `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`
- WeasyPrint archive SHA-256: `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`
- Calibre MSI SHA-256: `4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d`

## Latest accepted milestone — Calibre

Complete primary Run #96 (`33748509811`), job `100626447125`, commit `0874881eaadcede5095e3db0052ce8b78cc23906`, passed every primary step and formally accepts Calibre 9.14.0.

Calibre package contract:

- official Windows x64 MSI `calibre-64bit-9.14.0.msi`;
- MSI SHA-256 `4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d`;
- administrative extraction only, never runner installation;
- backend `tools/calibre/ebook-convert.exe`;
- literal package-relative launcher `tools/bin/ebook-convert.exe`;
- config/cache under `data/calibre`, temp under `data/tmp/calibre`, `CALIBRE_NO_DEFAULT_PROGRAMS=1`;
- real Stirling PDF→EPUB and eBook→PDF routes accepted;
- relocation with spaces and prior dependency regressions accepted.

Run #96 generated `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`, size `1,837,322,506` bytes, SHA-256 `724C882195965A9F5676ADB6B4ED09FE1ED32EED09D74424D76DEF7B59C7CCAE`; the ZIP was not uploaded. Layout: `31,400` files / `4,228,817,694` payload bytes. Lightweight artifact `9891758584` is `7,273` bytes with Actions digest `sha256:d03923535d0b2d9e61aa4ea7ed3f82e84ae241d8380abd4a62d77b2874431bf7`, expires 2026-09-10.

Calibre is closed/accepted; do not reopen it without new evidence.

## Active candidate — unpaper + pngquant

Pinned-source audit conclusion:

- Stirling 2.14.3 standard runtime installs `unpaper` and `pngquant`, but `ExternalAppDepConfig` does not expose them as independent feature groups.
- Stirling's OCR controller passes `--clean` and `--clean-final` to OCRmyPDF when requested.
- Accepted OCRmyPDF `17.10.0` uses literal `unpaper` through `ToolProbe` and its `run_unpaper` wrapper for cleaning.
- Accepted OCRmyPDF `17.10.0` uses literal `pngquant` through `ToolProbe` and its `quantize` wrapper for optimization levels 2/3.
- OCRmyPDF 17.10.0 has no minimum-version gate for either command.

Candidate identity:

### unpaper 6.1 Windows x86_64

- source: `rodrigost23/unpaper` release `unpaper-6.1`;
- archive: `unpaper-6.1-windows-x86_64.zip`;
- SHA-256: `a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65`;
- staged files: `tools/bin/unpaper.exe`, `LIBBZ2-1.DLL`, `LIBWINPTHREAD-1.DLL`, `ZLIB1.DLL`;
- provenance exception: this is a community Windows x64 build. Current official upstream unpaper release `7.0.0` publishes source only and has no Windows binary asset. Do not label 6.1 as an official upstream Windows binary.

### pngquant 3.0.3 Windows

- source: official `https://pngquant.org/pngquant-windows.zip`;
- SHA-256: `bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d`;
- staged executable: `tools/bin/pngquant.exe`.

Candidate validation contract:

1. authenticate both archives by exact SHA-256 before extraction;
2. require AMD64 PE identity for executables and unpaper sibling DLLs;
3. isolate PATH and require `where.exe` to resolve only package copies;
4. prove exact version identities;
5. prove OCRmyPDF 17.10.0 detects both tools with its own `ToolProbe` layer;
6. execute OCRmyPDF's actual `unpaper.run_unpaper` wrapper with its production-style arguments;
7. execute OCRmyPDF's actual `pngquant.quantize` wrapper, including stdin/stdout semantics implemented by OCRmyPDF;
8. run real OCRmyPDF with Stirling-exposed `--clean --clean-final` flags;
9. prove auxiliary binaries remain functional from a relocated path containing spaces;
10. preserve every earlier primary gate and final package/layout evidence.

CI implementation intentionally preserves the accepted Python/OCRmyPDF preparation logic byte-for-byte as `.github/scripts/prepare-ocrmypdf-core.ps1` (same blob as the previously accepted `.github/scripts/prepare-ocrmypdf.ps1`). The existing workflow entry path `.github/scripts/prepare-ocrmypdf.ps1` is now a narrow wrapper: run the accepted core, then `.github/scripts/prepare-ocr-aux.ps1`. This avoids rewriting the accepted Python/lock/OpenCV preparation logic while adding the new block.

**Do not call unpaper/pngquant accepted until the complete primary workflow is green with this candidate and every earlier gate enabled.**

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency moves to accepted only when the complete primary workflow is green with every earlier accepted gate enabled. Record commit SHA, Run/number, job ID, exact source/version/hash and artifact/digest when relevant. Standalone `--version` or a narrow direct probe alone is never acceptance.

Before causing a new heavy regression, confirm no useful run is queued/in-progress. Do not rerun blindly after failure: inspect jobs/logs and bounded diagnostics, establish a concrete root cause, apply the smallest justified correction, then run one complete primary regression. Do not increase timeouts blindly or weaken gates.

## CI artifact storage policy

The primary workflow builds and validates the portable ZIP but ordinary CI uploads only lightweight evidence: package hash/size, provenance, dependency lock/inventory and layout summary. Do not upload the portable ZIP, Python wheelhouses, dependency archives or caches during ordinary iterations. Failure diagnostics are bounded/text-only. Final portable ZIP is a Release asset only after all v1 gates and explicit user authorization.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. **unpaper 6.1 + pngquant 3.0.3** — active OCRmyPDF auxiliary candidate;
2. conversion fonts;
3. explicit VeraPDF E2E;
4. investigate/build/package `jbig2enc` if viable;
5. viable portable RAR/CBR or a concrete documented limitation;
6. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Representative E2E must cover Office→PDF and supported PDF→Office, HTML/URL/base-URL/EML, accepted WeasyPrint, accepted Poppler, accepted Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF regressions, `unpaper`/`pngquant`, RAR/CBR and jbig2enc if integrated, and representative Stirling API families. Prove runner-installed software is never satisfying package tests.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove retired focused/integration/diagnostic mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish clean v1 ZIP only when all gates are complete and explicitly authorized;
9. manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-09-03

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python 3.12.14 + OCRmyPDF 17.10.0; authenticated portable Python lock; NumPy 2.5.2; OpenCV `opencv-python-headless 4.14.0.94` / runtime `4.14.0`; LibreOffice 26.2.5 + native `unoconvert`; Poppler 26.02.0; WeasyPrint 69.0; **Calibre 9.14.0**.

Latest complete green primary: **Run #96** (`33748509811`), job `100626447125`, commit `0874881eaadcede5095e3db0052ce8b78cc23906`. ZIP SHA-256 `724C882195965A9F5676ADB6B4ED09FE1ED32EED09D74424D76DEF7B59C7CCAE`, size `1,837,322,506`; evidence artifact `9891758584`, `7,273` bytes, digest `sha256:d03923535d0b2d9e61aa4ea7ed3f82e84ae241d8380abd4a62d77b2874431bf7`.

Active candidate: **unpaper 6.1 + pngquant 3.0.3** as OCRmyPDF auxiliaries. The next complete primary run is the acceptance gate. If it passes, update README + AGENTS in one `[skip ci]` documentation-only commit to record formal acceptance and move the active block to conversion fonts; do not spend another heavy CI run merely to record documentation.

## Compact changelog

- 2026-08-21–27: fork/Tauri architecture and portable containment established; WebView2, qpdf, ImageMagick, Ghostscript and Tesseract accepted.
- 2026-08-28: Python 3.12.14 + OCRmyPDF 17.10.0 accepted via complete Run #77.
- 2026-09-01: LibreOffice/unoconvert accepted #83; Poppler #86; Python lock/NumPy #87/#90; OpenCV #92.
- 2026-09-03: WeasyPrint 69.0 formally accepted via complete Run #95.
- **2026-09-03: Calibre 9.14.0 formally accepted via complete Run #96 (`33748509811`), job `100626447125`, commit `0874881eaadcede5095e3db0052ce8b78cc23906`.**
- **2026-09-03: opened the combined OCRmyPDF auxiliary block for unpaper 6.1 + pngquant 3.0.3 with authenticated Windows payloads, package-first validation, exact OCRmyPDF wrapper tests and relocation gate.**
