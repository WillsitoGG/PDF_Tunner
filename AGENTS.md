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
- LibreOffice → `<portable>/tools/libreoffice`; `unoconvert.exe` → `<portable>/tools/bin`;
- conversion fonts → `<portable>/tools/libreoffice/share/fonts/truetype`; metadata → `<portable>/tools/fonts`;
- Poppler → `<portable>/tools/poppler/Library/bin`;
- WeasyPrint → `<portable>/tools/weasyprint`; shim → `<portable>/tools/bin/weasyprint.exe`;
- Calibre → `<portable>/tools/calibre`; launcher → `<portable>/tools/bin/ebook-convert.exe`; config/cache/temp remain package-local;
- OCRmyPDF auxiliaries → `<portable>/tools/bin/unpaper.exe` with required sibling DLLs and `<portable>/tools/bin/pngquant.exe`;
- embedded VeraPDF → inside `app.jar`; bundled JRE must include `jdk.dynalink`;
- skip `pdf-tunner://` deep-link registration in portable mode.

## External dependency source of truth

For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- controllers/services executing each feature;
- exact accepted third-party package source when a dependency is mediated through OCRmyPDF or another bundled runtime;
- embedded dependency declarations in `app/core/build.gradle` when there is no external executable.

Direct runtime probes include Ghostscript `gs`, OCRmyPDF `ocrmypdf`, LibreOffice `soffice`, WeasyPrint `weasyprint`, Poppler `pdftohtml`, UNO `unoconvert`, qpdf `qpdf`, Tesseract `tesseract`, Calibre `ebook-convert`, ImageMagick `magick`, Python, OpenCV import, OCRmyPDF ToolProbe for `unpaper`/`pngquant`, and real API-level VeraPDF verification.

Also audit `jbig2enc`, RAR/CBR and any additional exact dependency exposed by pinned source.

## Accepted layers and evidence

| Layer | Acceptance evidence |
| --- | --- |
| Native portable/Tauri containment | consolidated proof includes Run `32825188381` |
| Fixed WebView2 `151.0.4129.101` x64 | Run #62 `33058462619` |
| qpdf `12.4.0` | Run #66 `33086404875` |
| ImageMagick `7.1.2-30` | Run #67 `33092698357` |
| Ghostscript `10.07.1` | Run #68 `33104114920` |
| Tesseract `5.5.3` / CLI `5.5.3.20260724` | Run #70 `33122172947` |
| Python `3.12.14` + OCRmyPDF `17.10.0` | Run #77 `33201568275` |
| LibreOffice `26.2.5` + native `unoconvert` | Run #83 `33497784837` |
| Poppler `26.02.0` | Run #86 `33507551477` |
| authenticated Python lock + NumPy `2.5.2` | Run #90 `33530454097` |
| OpenCV `4.14.0.94` / runtime `4.14.0` | Run #92 `33557169326` |
| WeasyPrint `69.0` | Run #95 `33695530172` |
| Calibre `9.14.0` | Run #96 `33748509811` |
| unpaper `6.1` + pngquant `2.17.0` | Run #99 `33786563784` |
| **conversion fonts** | **Run #103 `33896293861`, job `101099606785`, commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f`** |

### Fixed provenance values that must not drift silently

- WebView2 CAB SHA-256: `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`
- qpdf archive SHA-256: `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`
- ImageMagick archive SHA-256: `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`
- Ghostscript installer SHA-256: `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`
- Tesseract installer SHA-256: `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`
- Python archive SHA-256: `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`
- OCRmyPDF wheel SHA-256: `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`
- Python dependency lock SHA-256: `ededb999049d81b85527f4d4aa679179e747669df300083d91bc2dd4e14e430f`
- NumPy wheel SHA-256: `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`
- OpenCV wheel SHA-256: `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`
- LibreOffice MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`
- Poppler archive SHA-256: `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`
- WeasyPrint archive SHA-256: `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`
- Calibre MSI SHA-256: `4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d`
- unpaper archive SHA-256: `a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65`
- pngquant archive SHA-256: `bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d`
- Noto CJK `Sans2.004` Regular subset SHA-256 values remain exactly those documented in README; do not change them without new authenticated evidence.

## Latest accepted milestone — conversion fonts

Runs #100–#101 failed at the new font staging path. Run #102 (`33861701712`), job `100987374348`, commit `05c5121e197fd43a25b70d8c25ceed3d1141357d`, supplied the decisive bounded diagnostic: `CORE_SUCCESS`, then `FONTS_FAILURE` because the authenticated LibreOffice MSI `Fonts` payload had not been preserved in `tools/libreoffice/share/fonts/truetype`.

Commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f` made the smallest justified correction: preserve that same MSI font payload during the existing administrative extraction, then add the already authenticated five Noto Sans CJK `Sans2.004` Regular subsets. No LibreOffice URL/SHA, CJK hash or existing gate was weakened.

Complete primary Run #103 (`33896293861`), job `101099606785`, passed every step and formally accepts conversion fonts. Evidence: ZIP size `1,909,704,241`, SHA-256 `26F9CE12AB4A949F0FB0BBEE503F630AFF7D457D2EBB6AB990E57DC78B57FE00`, layout `31,611` files / `4,387,634,585` payload bytes, lightweight artifact `9947175939` size `7,580`, digest `sha256:4ab2522e4baa8a3de6fcbe421191a31f81274d3940112e8c7d7785e8be19c963`. The ZIP itself was not uploaded.

Conversion fonts are closed/accepted; do not reopen them without new evidence.

## Active candidate — embedded VeraPDF 1.30.2 E2E

VeraPDF is embedded in Stirling's Java application, not staged as an external executable. The pinned core declares `org.verapdf:validation-model:1.30.2`; the bundled desktop JRE includes `jdk.dynalink`, explicitly required by Stirling for VeraPDF runtime operation.

Implementation contract:

- add `.github/scripts/validate-verapdf.ps1`;
- keep standalone LibreOffice validation independent of a running app;
- invoke VeraPDF E2E only from the live-backend invocation of `validate-libreoffice.ps1` so the existing heavy workflow does not gain redundant staging/download steps;
- prove the source still pins VeraPDF `1.30.2`;
- prove package-local Java `--list-modules` contains `jdk.dynalink`;
- convert `test_globalsign.pdf` using real `/api/v1/convert/pdf/pdfa` with `outputFormat=pdfa-2b`;
- verify that generated file through real `/api/v1/security/verify-pdf`;
- require declared PDF/A, compliant result, zero failures and PDF/A-2b identity;
- require backend log evidence of successful VeraPDF Greenfield initialization and completion of the verification controller;
- add no new VeraPDF binary/download/payload;
- preserve every earlier primary gate and the lightweight-artifact policy.

**Do not accept VeraPDF E2E until one complete primary workflow is green with this gate enabled.**

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency or functional layer moves to accepted only when the complete primary workflow is green with every earlier accepted gate enabled. Record commit SHA, Run/number, job ID, exact source/version/hash or embedded identity, and artifact/digest when relevant. Standalone `--version`, file existence or a narrow direct probe alone is never acceptance.

Before causing a new heavy regression, confirm no useful run is queued/in-progress. Do not rerun blindly after failure: inspect jobs/logs and bounded diagnostics, establish a concrete root cause, apply the smallest justified correction, then run one complete primary regression. Do not increase timeouts blindly or weaken gates.

## CI artifact storage policy

The primary workflow builds and validates the portable ZIP but ordinary CI uploads only lightweight evidence: package hash/size, provenance, dependency lock/inventory and layout summary. Do not upload the portable ZIP, Python wheelhouses, dependency archives or caches during ordinary iterations. Final portable ZIP is a Release asset only after all v1 gates and explicit user authorization.

## Remaining v1 roadmap — do not collapse

### A. External toolchain / embedded runtime parity

1. **embedded VeraPDF E2E** — active candidate;
2. investigate/build/package `jbig2enc` if viable;
3. viable portable RAR/CBR or a concrete documented limitation;
4. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Representative E2E must cover Office→PDF and supported PDF→Office, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, VeraPDF, RAR/CBR and jbig2enc if integrated, and representative Stirling API families. Prove runner-installed software is never satisfying package tests.

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

## Current handoff — 2026-09-04

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python 3.12.14 + OCRmyPDF 17.10.0; authenticated Python lock; NumPy 2.5.2; OpenCV `4.14.0.94`; LibreOffice 26.2.5 + native `unoconvert`; Poppler 26.02.0; WeasyPrint 69.0; Calibre 9.14.0; unpaper 6.1 + pngquant 2.17.0; **package-local conversion fonts**.

Latest complete green primary: **Run #103** (`33896293861`), job `101099606785`, commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f`; lightweight artifact `9947175939`, digest `sha256:4ab2522e4baa8a3de6fcbe421191a31f81274d3940112e8c7d7785e8be19c963`.

Active candidate: **embedded VeraPDF 1.30.2 E2E**. New gate validates package-local `jdk.dynalink`, performs real PDF→PDF/A-2b conversion, verifies the output through `/api/v1/security/verify-pdf`, and requires compliant/zero-failure + backend log evidence. No external VeraPDF runtime is added. Once accepted, proceed to **`jbig2enc` feasibility/integration**.
