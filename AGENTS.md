# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository.

## Identity, base and target

PDF_Tunner is the real fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

- Pinned upstream version: `2.14.3`
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: Windows 10/11 x64 portable ZIP, extract and run.
- Preserve Stirling non-Enterprise functionality unless explicitly removed.
- Bundle required runtimes/dependencies whenever technically viable.
- Keep runtime config/cache/log/temp/state inside the portable tree as far as underlying Windows APIs permit.
- Keep the downstream delta small and easy to rebase on Stirling upstream.
- No final PDF_Tunner v1 Release exists yet; `main` remains the clean upstream base while v1 is developed.

## Mandatory repository rules

1. Preserve Stirling's root structure; do not reorganize the fork into generic archive/source roots.
2. Keep `main` clean: no generated builds, logs, abandoned experiments, one-shot triggers or temporary scripts.
3. Preserve upstream behavior unless the user requests removal or functionality is outside target.
4. Compilation alone is never validation. Validate the assembled portable app and real operations.
5. Never archive failed/intermediate builds as release history.
6. Keep SHA-256/provenance and exact dependency identity reproducible.
7. **Every PDF_Tunner-specific change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
8. Heavy CI must use branch/workflow-specific concurrency with `cancel-in-progress: true`.
9. Use at most one automatic trigger per heavy workflow unless technically necessary.
10. Remove development-only focused workflows/triggers when their phase is complete and before final `main`.
11. Do not reopen old PR #1 as the v1 release integration vehicle.
12. Do not publish a final Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete, and never without explicit user authorization.

## Continuity protocol

Before writes in a resumed conversation:

1. recover the most recent PDF_Tunner handoff;
2. read current project rules, README and AGENTS;
3. verify live branch HEAD, latest primary Actions run, PR state and Release state;
4. carry accepted/closed, active candidate, next block and broader roadmap explicitly;
5. never treat one immediate task as the only remaining work;
6. at each accepted milestone record commit, Run/job, artifact/digest where relevant, next candidate and remaining roadmap in README + AGENTS;
7. before final Release re-audit against the full original PDF_Tunner objective.

## Architecture and portable boundary

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`. Do not restore the old `PDF_Tunner_Legacy` .NET/WebView2 launcher architecture.

Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable.

Do **not** globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before Tauri/WebView2 initializes. Use component-specific localization:

- `PDF_TUNNER_PORTABLE_ROOT` -> executable directory;
- Stirling app data -> `<portable>/data`;
- Java temp -> `<portable>/data/tmp` through `JAVA_TOOL_OPTIONS`;
- WebView2 user data -> `<portable>/data/webview2`;
- Tauri logs/store/window-state/http cookies -> `<portable>/data/tauri/...`;
- ImageMagick config -> `<portable>/tools/imagemagick`, temp -> `<portable>/data/tmp/imagemagick`;
- Ghostscript -> package-first `<portable>/tools/ghostscript/bin`;
- Tesseract -> package-first `<portable>/tools/tesseract`, `TESSDATA_PREFIX=<portable>/tools/tesseract/tessdata`;
- Python/OCRmyPDF -> `<portable>/tools/python`; OCRmyPDF child temp -> `<portable>/data/tmp/ocrmypdf`; Python cache -> `<portable>/data/python-cache`;
- LibreOffice -> `<portable>/tools/libreoffice`; native source-compatible `unoconvert.exe` -> `<portable>/tools/bin`; transient state must remain package-local and cleaned;
- Poppler -> `<portable>/tools/poppler`, executables under `Library/bin`;
- WeasyPrint official Windows payload -> `<portable>/tools/weasyprint`; package-relative command shim -> `<portable>/tools/bin/weasyprint.exe`; per-invocation PyInstaller/temp state -> `<portable>/data/tmp/weasyprint` and must be removed after each invocation;
- Calibre config -> `<portable>/data/calibre` when packaged;
- skip `pdf-tunner://` deep-link registration in portable mode.

## External dependency source of truth

For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- controllers/services executing each feature.

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

Also audit Poppler `pdfinfo`/`pdfimages`, `unpaper`, `pngquant`, NumPy/OpenCV, WeasyPrint, LibreOffice/UNO, Calibre, conversion fonts, VeraPDF E2E, `jbig2enc` and any additional exact dependency exposed by pinned source.

## Tool layout strategy

Package under one `tools/` subtree per dependency. Tauri prepends, when present: `tools/bin`, Python/Scripts, LibreOffice program, Tesseract, Ghostscript, qpdf, Poppler `Library/bin`, WeasyPrint backend, ImageMagick, Calibre and any later accepted tool subtree. If Windows executable naming differs from Stirling's literal probe, provide a deterministic package-local alias/shim only after proving the exact probe. Never count runner-installed software as package evidence.

## Accepted layers and evidence

### Native portable/Tauri containment — accepted

Real packaged startup/backend health, Java temp localization, WebView2 profile localization, package-local Tauri stores/logs/http cookies, protocol containment, normal process-tree cleanup and two-launch window-state persistence are accepted. Run `32825188381` is the key consolidated AppData/window-state proof.

### Fixed WebView2 — accepted

`151.0.4129.101` x64; official CAB SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`; acceptance Run #62 (`33058462619`), job `98471041328`, commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4`.

### qpdf — accepted

`12.4.0` MinGW64; SHA-256 `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`; acceptance Run #66 (`33086404875`), job `98567113737`, commit `413994c9ea368b5144a26686afef6011eba8de59`.

### ImageMagick — accepted

`7.1.2-30` portable Q16 x64; SHA-256 `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`; acceptance Run #67 (`33092698357`), job `98589465377`, commit `d1801e8569a23a762035a39dc7295de0f19e6115`.

### Ghostscript — accepted

`10.07.1` Win64; SHA-256 `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`; acceptance Run #68 (`33104114920`), job `98629258424`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004`.

### Tesseract — accepted

Release `5.5.3`, Windows CLI `5.5.3.20260724`; installer SHA-256 `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`; acceptance Run #70 (`33122172947`), job `98691480028`, commit `52429eb7812e8615ee39aab695641d495798c1ba`.

### Python 3.12.14 + OCRmyPDF 17.10.0 — accepted

Python archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`; OCRmyPDF wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`. Native package-relative launcher executes sibling Python and localizes OCRmyPDF temp/cache. Acceptance Run #77 (`33201568275`), job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31`, proved package-only resolution, real searchable-PDF OCR, relocation with spaces and live backend acceptance.

### Portable Python dependency lock + NumPy 2.5.2 — accepted

The accepted 28-package lock SHA-256 is `ededb999049d81b85527f4d4aa679179e747669df300083d91bc2dd4e14e430f`; NumPy Windows AMD64 wheel SHA-256 is `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`. Preparation must remain authenticated/offline after download and validation must preserve exact inventory, compiled AMD64 identity, deterministic matrix and relocation gates. Acceptance Run #90 (`33530454097`), job `99931980241`, commit `c32fb84eb2c0f7b157ef3217c59e57eee20b895b`.

### OpenCV 4.14.0.94 — accepted

Use `opencv-python-headless 4.14.0.94`, wheel SHA-256 `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`, dedicated lock SHA-256 `ec341586a884015445d4e28debbdd00b57ac903a36405bc7e0b9020e12dfd6c6`. Preserve separate distribution `4.14.0.94` and runtime/core `4.14.0` identity checks. Acceptance Run #92 (`33557169326`), job `100020722841`, commit `c4c2b7f6e320840faf3d8c61967351b529875a50`, passed real Stirling `split_photos.py`, AMD64, relocation, OCR/NumPy regression and live backend gates.

### LibreOffice 26.2.5 + native `unoconvert` — accepted

Official Windows x86-64 MSI SHA-256 `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`. CI uses administrative extraction, never runner installation. Native package-relative `unoconvert.exe` translates Stirling CLI to bundled LibreOffice, localizes state and cleans profiles. Acceptance Run #83 (`33497784837`), job `99823839704`, commit `355c0cf5cfe7afaadd89933a0aa3fb13456ebb83`, passed real Office→PDF/PDF→DOCX routes and relocation.

### Poppler 26.02.0 — accepted

Pinned `oschwartz10612/poppler-windows` archive SHA-256 `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`. Preserve package-local `pdftohtml`, `pdfinfo`, `pdfimages`, isolated resolution, real commands, relocation and Stirling PDF→HTML. Acceptance Run #86 (`33507551477`), job `99855128441`, commit `1b2bfdc4e99d87aa899a0701291db496f740f7ab`.

### WeasyPrint 69.0 — accepted

Source-backed scope: pinned Stirling defaults to literal `weasyprint`, requires version `58.0` or newer and executes `weasyprint -e utf-8 -v --pdf-forms INPUT OUTPUT`. HTML, Markdown and EML paths use the shared renderer.

Accepted payload: official Kozea WeasyPrint `69.0` Windows asset `weasyprint-windows.zip`, published 2026-06-02, size `29,832,155` bytes, archive SHA-256 `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`. Stage official backend at `tools/weasyprint/weasyprint.exe`; build native package-relative literal command at `tools/bin/weasyprint.exe`. The shim forwards the complete CLI, localizes child `TEMP`/`TMP`/`TMPDIR` to a unique `data/tmp/weasyprint/run-<pid>-<timestamp>` directory and removes it on exit. Do not merge WeasyPrint into the accepted Python/OCRmyPDF lock.

Run #94 (`33666446582`), job `100369276881`, commit `3afffbc52eb2450eede8ea112ce0628a0bd8b3c4`, retained bounded diagnostics proving Stirling started and both real WeasyPrint HTML→PDF and Markdown→PDF routes were healthy. Its failure was validator-only: Stirling patch-normalized the log identity to `WeasyPrint 69.0.0 meets minimum 58.0.0`, while the validator demanded shorter `69.0` / `58.0` literals.

Functional corrective commit `a7a118e852277069c8ab13cc2f25121f9be87fea` changed only the dependency-log assertion to accept that semantic patch normalization. It did **not** change the `69.0` payload, archive hash, shim, PATH, CLI, endpoints, timeout or any accepted gate.

**Complete primary Run #95 (`33695530172`), job `100463449110`, commit `a7a118e852277069c8ab13cc2f25121f9be87fea`, passed every primary step and formally accepts WeasyPrint 69.0.** It proved exact source/hash/AMD64, isolated package-only command resolution, exact version, real Stirling-shaped HTML→PDF, no residual invocation temp, relocation with spaces, real live-backend HTML→PDF + Markdown→PDF, enabled dependency group, actual `Running command: weasyprint`, all prior accepted gates, backend startup, portable state/process cleanup, final layout and ZIP generation.

Run #95 generated `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`, size `1,553,629,801` bytes, SHA-256 `CFD09D41CC5E074B7CEF1885F5A32ED58F08E2FE6FB9EEBC0C0AA07B2A16C0FE`; the ZIP was not uploaded. Lightweight evidence artifact `9872300027` is `6,055` bytes, Actions digest `sha256:e54704632653500d4514dd41c24340d598c66de547ac81e1a06e8d3d30d3468f`, expires 2026-09-09. Layout: `30,051` package files / `3,569,719,817` payload bytes. WeasyPrint is closed/accepted; do not reopen it without new evidence.

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency moves to accepted only when the **complete primary workflow** is green with every earlier accepted gate enabled. Record commit SHA, Run/number, job ID, exact source/version/hash and artifact/digest when relevant. Standalone candidate workflow or `--version` alone is never acceptance. Require real operation and isolated package-first PATH/environment wherever practical.

Before causing a new heavy regression, confirm no useful run is queued/in-progress. Do not rerun blindly after failure: inspect jobs/logs and bounded diagnostics, establish a concrete root cause, apply the smallest justified correction, then allow exactly one complete primary regression. Do not increase timeouts blindly or weaken gates.

## CI artifact storage policy

The primary workflow builds and validates the portable ZIP but ordinary CI uploads only lightweight evidence: package hash/size, provenance, dependency lock/inventory and layout summary. Do not upload the multi-gigabyte portable ZIP, Python wheelhouses, dependency archives or caches during ordinary iterations. Failure diagnostics are text-only, bounded to 2 MB and prioritize selected package-local backend log tails plus concise process/state inventories. Large artifacts require a concrete evidence need and quota review. Final portable ZIP is a Release asset only after all v1 gates and explicit user authorization.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. **Calibre/`ebook-convert`** — next active candidate;
2. `unpaper`;
3. `pngquant`;
4. conversion fonts;
5. explicit VeraPDF E2E;
6. investigate/build/package `jbig2enc` if viable;
7. viable portable RAR/CBR or concrete documented limitation;
8. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Office -> PDF; supported PDF -> Office; HTML/URL -> PDF; accepted WeasyPrint; accepted Poppler; Calibre/EPUB; Python/NumPy/OpenCV; regressions across accepted qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF; `pngquant`/`unpaper`; RAR/CBR and jbig2enc if integrated; representative Stirling API families; explicit proof runner software is not satisfying package tests. HTML/URL/base-URL and EML breadth remains part of this representative E2E phase even though WeasyPrint itself is accepted.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove development push/status/focused diagnostic mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening PR #1;
8. publish clean v1 ZIP only when all gates are complete and explicitly authorized;
9. manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-09-03

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python 3.12.14 + OCRmyPDF 17.10.0; authenticated 28-package portable Python dependency lock with NumPy 2.5.2; OpenCV `opencv-python-headless 4.14.0.94` / runtime `4.14.0`; LibreOffice 26.2.5 + native `unoconvert`; Poppler 26.02.0; **WeasyPrint 69.0**.

Latest green primary regression and WeasyPrint acceptance evidence: **Run #95** (`33695530172`), job `100463449110`, functional commit `a7a118e852277069c8ab13cc2f25121f9be87fea`; ZIP SHA-256 `CFD09D41CC5E074B7CEF1885F5A32ED58F08E2FE6FB9EEBC0C0AA07B2A16C0FE`, size `1,553,629,801` bytes; evidence artifact `9872300027` (`6,055` bytes), Actions digest `sha256:e54704632653500d4514dd41c24340d598c66de547ac81e1a06e8d3d30d3468f`, expires 2026-09-09. Layout: `30,051` package files / `3,569,719,817` payload bytes.

Run #95 passed every earlier gate plus authenticated WeasyPrint source/hash, AMD64 identity, isolated package-first resolution, exact Stirling CLI execution, real HTML→PDF, relocation, live Stirling HTML→PDF + Markdown→PDF and dependency-log/command evidence. **WeasyPrint is formally accepted.**

Active candidate: **Calibre/`ebook-convert`**. Do not collapse the remaining roadmap. Before integrating it, inspect exact pinned Stirling source/probes/routes, choose a reproducible Windows payload and package-local state strategy, preserve every accepted gate, and avoid touching already accepted dependency versions unless new evidence requires it.

## Compact changelog

- **2026-08-21–23:** real fork/base confirmed; Stirling Tauri + JLink architecture selected; portable state containment and two-launch window-state proof established.
- **2026-08-27:** Fixed WebView2 accepted #62; qpdf #66; ImageMagick #67; Ghostscript #68; Tesseract #70.
- **2026-08-28:** primary Run #77 passed Python/OCRmyPDF with real OCR, relocation and backend acceptance.
- **2026-09-01:** LibreOffice 26.2.5 + native `unoconvert` accepted via complete primary Run #83.
- **2026-09-01:** Poppler 26.02.0 accepted via complete primary Run #86.
- **2026-09-01:** authenticated portable Python dependency lock accepted via complete primary Run #87; NumPy 2.5.2 accepted via complete Run #90.
- **2026-09-01:** OpenCV distribution/runtime semantic correction followed by complete primary Run #92; OpenCV formally accepted.
- **2026-09-02:** WeasyPrint 69.0 candidate integrated from official Kozea Windows asset with native package-relative temp-containment shim, authenticated hash, AMD64/PATH/direct/relocation and live-backend HTML→PDF + Markdown→PDF gates.
- **2026-09-02:** Run #94 bounded diagnostics proved WeasyPrint runtime/backend/routes healthy and isolated the only failure to patch-normalized dependency-log version formatting.
- **2026-09-03:** corrective commit `a7a118e852277069c8ab13cc2f25121f9be87fea` preserved payload and all gates; complete primary Run #95 (`33695530172`), job `100463449110`, passed every step. **WeasyPrint 69.0 formally accepted; Calibre is next.**
