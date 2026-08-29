# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository.

## Identity and target

PDF_Tunner is the real fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

- Pinned upstream version: `2.14.3`.
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`.
- Primary development branch: `pdf-tunner/windows-portable-v1`.
- Current focused branch: `pdf-tunner/libreoffice-uno-candidate`.
- Target: Windows 10/11 x64 portable ZIP, extract and run, no install/admin/global runtime requirement.
- Preserve Stirling non-Enterprise functionality unless explicitly removed.
- Keep `main` clean and upstream-comparable until v1 integration.
- No final v1 Release until toolchain, E2E, parity, branding, sandbox/portability, cleanup and documentation gates are complete.

For this project, **portable means sandbox-like containment**: application code, runtime engines, external tools, config, cache, logs, temp and mutable state remain inside the portable tree whenever technically possible. Host software must never silently satisfy a package test.

## Mandatory repository rules

1. Preserve Stirling's root structure; do not rebuild it behind a separate wrapper.
2. Preserve upstream behavior unless a portable-specific defect or explicit project requirement justifies a downstream change.
3. Compilation and `--version` checks alone are not sufficient validation; execute representative real operations.
4. Pin exact dependency version/source/SHA-256 and retain provenance.
5. **Every PDF_Tunner-specific repository change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
6. Heavy CI uses branch/workflow-specific `concurrency` with `cancel-in-progress: true`.
7. Development-only workflows/triggers/status bridges must be removed after their phase and before final `main`.
8. Do not reopen old PR #1 as the v1 integration vehicle.
9. Never publish a final Release from failed/intermediate builds.

## No-polling workflow rule

When work launches or depends on a GitHub Actions workflow/job:

- check its state at most once in that user turn;
- if it is `queued` or `in_progress`, stop dependent work and return control to the user;
- do not poll every few seconds/minutes;
- check again only when the user explicitly resumes/asks to continue;
- while a primary workflow with `cancel-in-progress: true` is running, do not push another commit to the same triggering branch unless needed to correct that run.

## Continuity protocol

Before resumed writes: recover the latest project handoff; read project prompt/rules plus current README/AGENTS; verify live branch HEAD and relevant Actions run once; carry forward accepted/closed work, active candidate, next block and broader roadmap; record accepted commit/run/job/artifact/digest evidence; re-audit the original objective before final Release.

## Architecture and sandbox boundary

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`; do not restore the old .NET/WebView2 wrapper architecture.

Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable. Do **not** globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before native Tauri/WebView2 initialization. Localize state per component.

Current boundaries:

- Stirling app data -> `<portable>/data`.
- Java temp -> `<portable>/data/tmp`.
- WebView2 profile -> `<portable>/data/webview2`.
- Tauri logs/store/window-state/http cookies -> `<portable>/data/tauri/...`.
- ImageMagick config/temp -> package-local tools / `<portable>/data/tmp/imagemagick`.
- Ghostscript -> `<portable>/tools/ghostscript/bin`.
- Tesseract -> `<portable>/tools/tesseract`, package-local tessdata.
- Python/OCRmyPDF -> `<portable>/tools/python`, OCR temp `<portable>/data/tmp/ocrmypdf`, Python cache `<portable>/data/python-cache`.
- LibreOffice -> `<portable>/tools/libreoffice`; TEMP/TMP/profile must be localized per child process.
- UNO/unoserver -> `<portable>/tools/unoserver`; server profile/temp under `<portable>/data/...`.
- Calibre config -> `<portable>/data/calibre` when packaged.
- Skip `pdf-tunner://` protocol registration in portable mode.

Portable Tauri prepends package tool directories including `tools/bin`, `tools/python`, `tools/python/Scripts`, `tools/libreoffice/program`, Tesseract, Ghostscript, qpdf, Poppler, ImageMagick, Calibre, pngquant, unpaper, rar and jbig2enc. If a Windows naming/launch mismatch conflicts with Stirling's literal probe, use a deterministic package-local native shim only after proving exact source behavior.

## External dependency source of truth

For Stirling 2.14.3 inspect at least `ExternalAppDepConfig.java`, `RuntimePathConfig.java`, `ProcessExecutor.java`, `PDFToFile.java`, `ConvertOfficeController.java`, Docker toolchain/startup scripts and feature controllers/services.

Direct probes include: `gs`, `ocrmypdf`, `soffice`, `weasyprint`, `pdftohtml`, `unoconvert`, `qpdf`, `tesseract`, `rar`, `ebook-convert`, `magick`, Python and Python `import cv2`.

`ProcessExecutor` recognizes `unoconvert`/`unoconv` as UNO conversions and injects `--host`/`--port`. Auto XML-RPC endpoints start at `127.0.0.1:2003`; Docker pairs the first with LibreOffice UNO port `2004`. `ConvertOfficeController` and `PDFToFile` try `unoconvert` first and fall back to `soffice`, while `ExternalAppDepConfig` probes LibreOffice and Unoconvert independently. Full parity therefore requires both probes to be intentionally resolved.

## Accepted layers and evidence

- Native portable/Tauri containment: accepted.
- Fixed WebView2 `151.0.4129.101`, SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`, Run `33058462619` (#62).
- qpdf `12.4.0`, SHA-256 `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`, Run `33086404875` (#66).
- ImageMagick `7.1.2-30`, SHA-256 `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`, Run `33092698357` (#67).
- Ghostscript `10.07.1`, SHA-256 `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`, Run `33104114920` (#68).
- Tesseract release `5.5.3`, Windows CLI `5.5.3.20260724`, Run `33122172947` (#70).
- Python `3.12.14` + OCRmyPDF `17.10.0`: accepted in primary Run `33201568275` (#77), job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31`, artifact `9698621272`, digest `sha256:68f69bb0d4ed6b731aefee82abff3eba7b01d18c5b270051e2e546337cd6a164`.
- Post-OCR full regression Run `33251329173` (#78), job `99097401718`, commit `694c1a01ac495bb906a3257b9c499b90ebb8b5db`, artifact `9714686816`, digest `sha256:740054517fa9733ae9f40e8a8fe319535f6fda0f5d1b5839744f984b8d354fbc`.

## Active focused candidate — LibreOffice 26.2.5 + unoserver 3.7

Pins:

- LibreOffice `26.2.5` Windows x86-64 official MSI.
- MSI SHA-256 `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`.
- unoserver `3.7` PyPI wheel.
- wheel SHA-256 `fc44e6808071c9d2957e705ecf1742cea8a582aa5d5cc23babf36bb332ec6e8e`.

Focused branch/workflow: `pdf-tunner/libreoffice-uno-candidate`, `.github/workflows/pdf-tunner-libreoffice-uno-candidate.yml`.

Current candidate contract:

1. download official MSI and enforce SHA-256;
2. administrative-extract without installing LibreOffice;
3. copy suite to `tools/libreoffice` **without launching any LibreOffice binary**;
4. resolve/download exact PyPI wheel and enforce SHA-256;
5. extract unoserver under `tools/unoserver`;
6. relocate the genuinely cold candidate to a path containing spaces before the first runtime version check or functional LibreOffice start;
7. validate runtime version only after relocation;
8. require two consecutive real DOCX -> PDF conversions with package-local profile/TEMP/TMP/I/O;
9. require zero package-local LibreOffice residual processes after each conversion;
10. require LibreOffice `program/python.exe` to import `uno` plus pinned unoserver;
11. start real unoserver at XML-RPC `127.0.0.1:2003`, UNO `127.0.0.1:2004`, package-local profile/temp;
12. execute a real unoconvert DOCX -> PDF conversion;
13. emit compact provenance/feasibility evidence.

Focused green is candidate evidence only. Acceptance requires integration into `pdf-tunner/windows-portable-v1` and a complete primary workflow with every earlier gate still green.

### Candidate diagnostic history

- Run `33252792182` (#1), job `99101259425`: harness `$LASTEXITCODE` defect after successful MSI download/hash/admin extraction; no product conclusion.
- Run `33253632305` (#2), job `99103473257`: original DOCX -> PDF passed; relocated harness still used `soffice.exe` for CLI/headless.
- Run `33254174353` (#3), job `99104896585`: `soffice.com` fixed launcher choice, but moving an already-used tree still failed.
- Run `33254797382` (#4), job `99106520093`: zero residual LibreOffice processes before relocation; residual-process hypothesis rejected.
- Run `33256042222` (#5), job `99109804816`, artifact `9715865060`, digest `sha256:f6711db687a6938b9c787fad7d1c95dd15a3b4ab1a28a217b45f2a459b611494`: decisive cold-copy matrix. `EXTERNAL_ALL`, `PACKAGE_PROFILE`, `PACKAGE_IO`, `PACKAGE_TEMP`, and `ALL_PACKAGE` all passed. Official Windows LibreOffice exposes `program/python.exe`; source and relocated interpreters returned `PYUNO_OK` and imported unoserver `3.7`.
- Run `33256677474` (#6), job `99111522324`, artifact `9716045830`, digest `sha256:dd23b222a4910c588e9fa30e9b76621fb9dfb2a8453579a0ce637bc59cbc00ca`: matrix passed again, but strict `direct-first-use` failed because preparation had already run `soffice --version`; the source was therefore not genuinely cold before `Move-Item`. Run #7 removes all LibreOffice execution from preparation, defers runtime version validation until after relocation, and removes the already-proven matrix from the automatic pre-validation path so no earlier LibreOffice instance can contaminate the strict gate.

Moving an already-used LibreOffice tree remains an explicit portability edge case for final v1 audit/mitigation; do not silently claim it is solved.

## Primary acceptance contract

A dependency moves to accepted only when the complete primary workflow is green with every earlier accepted gate enabled. A standalone focused workflow is diagnostic/candidate evidence only. Runner-installed software must not satisfy package validation.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. LibreOffice focused proof and primary integration.
2. UNO/`unoconvert` primary integration with deterministic startup/shutdown and sandboxed profile/temp.
3. Poppler: `pdftohtml`, `pdfinfo`, `pdfimages`.
4. Consolidate portable Python dependency lock; NumPy; OpenCV.
5. WeasyPrint.
6. Calibre/`ebook-convert`.
7. `unpaper`; `pngquant`; conversion fonts.
8. Explicit VeraPDF E2E.
9. Investigate/build/package `jbig2enc` if viable.
10. Viable portable RAR/CBR or concrete documented limitation.
11. Any additional exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Office -> PDF; supported PDF -> Office; OCR; HTML/URL -> PDF; Poppler; WeasyPrint; Calibre/EPUB; Python/NumPy/OpenCV; regressions of qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF; `pngquant`/`unpaper`; representative Stirling API families; explicit proof that host tools are not satisfying tests.

### C. Release readiness

1. Non-Enterprise parity audit against pinned Stirling 2.14.3.
2. Final branding audit.
3. Final sandbox/portability/state/process audit, including multiple folders, paths with spaces, restricted locations, post-use relocation behavior and Windows 10/11 x64.
4. Remove development-only push/status/focused mechanisms.
5. Final downstream diff/output hygiene.
6. Final README/AGENTS/provenance/version/hash record.
7. Integrate to `main` without reopening PR #1.
8. Publish clean v1 ZIP only after all gates.
9. Manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-08-29

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python; OCRmyPDF. Post-OCR primary Run #78 is green.

Active work: focused Windows LibreOffice 26.2.5 + unoserver 3.7 feasibility on `pdf-tunner/libreoffice-uno-candidate`.

Next after candidate proof: integrate the proven LibreOffice/UNO mechanism into the primary portable package without regressing the accepted sandbox boundary, then move to Poppler.
