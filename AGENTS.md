# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository.

## Identity and target

PDF_Tunner is the real fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

- Pinned upstream version: `2.14.3`
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Primary development branch: `pdf-tunner/windows-portable-v1`
- Current focused branch: `pdf-tunner/libreoffice-uno-candidate`
- Target: Windows 10/11 x64 portable ZIP, extract and run.
- Preserve Stirling non-Enterprise functionality unless explicitly removed.
- Bundle required runtimes/dependencies whenever technically viable.
- Keep the downstream delta small and upstream-comparable.
- No final v1 Release until toolchain, E2E, parity, branding, sandbox/portability, cleanup and documentation gates are complete.

For this project, **portable means sandbox-like containment**: application code, runtime engines, external tools, config, cache, logs, temp and mutable state remain inside the portable tree whenever technically possible. Host software must never silently satisfy a package test.

## Mandatory repository rules

1. Preserve Stirling's root structure; do not reorganize the fork into generic archive/source roots.
2. Keep `main` clean and upstream-comparable.
3. Preserve upstream behavior unless a portable-specific defect or explicit project requirement justifies a downstream change.
4. Compilation and `--version` checks are not sufficient validation. Execute representative real operations.
5. Never archive failed/intermediate builds as Release history.
6. Pin exact dependency version/source/SHA-256 and retain provenance.
7. **Every PDF_Tunner-specific change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
8. Heavy CI uses branch/workflow-specific `concurrency` with `cancel-in-progress: true`.
9. Development-only workflows/triggers/status bridges must be removed after their phase and before final `main`.
10. Do not reopen old PR #1 as the v1 integration vehicle.
11. Do not publish a final Release until every roadmap gate is complete.

## No-polling workflow rule

When work launches or depends on a GitHub Actions workflow/job:

- check its state at most once in that user turn;
- if it is `queued` or `in_progress`, stop dependent work and return control to the user;
- do not poll every few seconds/minutes;
- check again only when the user explicitly resumes/asks to continue;
- while a primary workflow with `cancel-in-progress: true` is running, do not push another commit to the same triggering branch unless necessary to correct that run.

## Continuity protocol

Before resumed writes:

1. recover the latest project handoff/context;
2. read project prompt/rules plus current README and AGENTS;
3. verify live branch HEAD and relevant Actions run once;
4. carry forward accepted/closed, active candidate, next block and broader roadmap;
5. never collapse the roadmap into only the immediate next task;
6. record accepted milestone commit/run/job/artifact/digest where relevant;
7. re-audit the original objective before final Release.

## Architecture and sandbox boundary

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`. Do not restore the old `PDF_Tunner_Legacy` .NET/WebView2 launcher architecture.

Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable.

Do **not** globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before native Tauri/WebView2 initializes. Use component-specific localization.

Current boundaries:

- `PDF_TUNNER_PORTABLE_ROOT` -> executable directory;
- Stirling app data -> `<portable>/data`;
- Java temp -> `<portable>/data/tmp` via `JAVA_TOOL_OPTIONS`;
- WebView2 profile -> `<portable>/data/webview2`;
- Tauri logs/store/window-state/http cookies -> `<portable>/data/tauri/...`;
- ImageMagick -> config `<portable>/tools/imagemagick`, temp `<portable>/data/tmp/imagemagick`;
- Ghostscript -> package-first `<portable>/tools/ghostscript/bin`;
- Tesseract -> `<portable>/tools/tesseract`, package-local tessdata;
- Python/OCRmyPDF -> `<portable>/tools/python`, OCR temp `<portable>/data/tmp/ocrmypdf`, Python cache `<portable>/data/python-cache`;
- LibreOffice target -> `<portable>/tools/libreoffice`; its native TEMP/TMP/profile must be localized per child/process rather than by globally mutating Tauri's Windows profile environment;
- UNO package target -> `<portable>/tools/unoserver`; server profile/temp must be `<portable>/data/...`;
- Calibre config -> `<portable>/data/calibre` when packaged;
- skip `pdf-tunner://` deep-link registration in portable mode.

The Windows keyring/Credential Manager may remain authentication's first path and is not claimed to be package-contained; Tauri Store fallback is package-local.

## Tool PATH strategy

Portable Tauri prepends existing package directories in this order:

- `tools/bin`
- `tools/python`
- `tools/python/Scripts`
- `tools/libreoffice/program`
- `tools/tesseract`
- `tools/ghostscript/bin`
- `tools/qpdf/bin`
- `tools/poppler/Library/bin`
- `tools/imagemagick`
- `tools/calibre`
- `tools/pngquant`
- `tools/unpaper`
- `tools/rar`
- `tools/jbig2enc`

If Windows executable naming/launch semantics differ from Stirling's literal probe, use a deterministic package-local native shim only after proving the exact source behavior.

## External dependency source of truth

For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `app/common/src/main/java/stirling/software/common/util/ProcessExecutor.java`;
- `app/common/src/main/java/stirling/software/common/util/PDFToFile.java`;
- `app/core/src/main/java/stirling/software/SPDF/controller/api/converters/ConvertOfficeController.java`;
- Docker toolchain/startup scripts;
- controllers/services executing each feature.

Direct probes include:

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

`ProcessExecutor` recognizes `unoconvert`/`unoconv` as UNO conversions and injects `--host`/`--port` from its UNO endpoint pool. Auto endpoints start at XML-RPC `127.0.0.1:2003` and increment by two. Docker startup pairs the first endpoint with LibreOffice UNO port `2004`.

`ConvertOfficeController` and `PDFToFile` try `unoconvert` first and fall back to `soffice`, but `ExternalAppDepConfig` still treats `LibreOffice` and `Unoconvert` as independently probed dependency groups. Full parity therefore requires both probes to be intentionally resolved, not merely hidden by the fallback.

## Accepted layers and evidence

### Native portable/Tauri containment — accepted

Real packaged startup/backend health, Java temp localization, WebView2 profile localization, package-local Tauri stores/logs/http cookies, protocol containment, normal process-tree cleanup and two-launch window-state persistence are accepted.

### Fixed WebView2 — accepted

- `151.0.4129.101` x64;
- CAB SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`;
- acceptance Run `33058462619` (#62).

### qpdf — accepted

- `12.4.0` MinGW64;
- SHA-256 `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`;
- acceptance Run `33086404875` (#66).

### ImageMagick — accepted

- `7.1.2-30` portable Q16 x64;
- SHA-256 `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`;
- acceptance Run `33092698357` (#67).

### Ghostscript — accepted

- `10.07.1` Win64;
- SHA-256 `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`;
- package-local `gs.exe` satisfies Stirling's literal probe;
- acceptance Run `33104114920` (#68).

### Tesseract — accepted

- release `5.5.3`, Windows CLI `5.5.3.20260724`;
- installer SHA-256 `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`;
- `tessdata_fast` commit `87416418657359cb625c412a48b6e1d6d41c29bd`;
- accepted Run `33122172947` (#70).

### Python + OCRmyPDF — accepted

- Python `3.12.14` x64, archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0`, wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`;
- native relative `tools/python/ocrmypdf.exe` launcher resolves sibling `python.exe`;
- real searchable OCR, package-only dependencies, temp/cache localization and relocation path-with-spaces proven;
- accepted in primary Run `33201568275` (#77), job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31`;
- artifact `9698621272`, digest `sha256:68f69bb0d4ed6b731aefee82abff3eba7b01d18c5b270051e2e546337cd6a164`.

### Post-OCR regression — green

Run `33251329173` (#78), job `99097401718`, commit `694c1a01ac495bb906a3257b9c499b90ebb8b5db` reconfirmed every accepted gate, real backend startup, relocation/state checks, final cleanup, ZIP and SHA. Artifact `9714686816`, digest `sha256:740054517fa9733ae9f40e8a8fe319535f6fda0f5d1b5839744f984b8d354fbc`.

## Active focused candidate — LibreOffice 26.2.5 + unoserver 3.7

Candidate pins:

- LibreOffice `26.2.5` Windows x86-64 official MSI;
- MSI SHA-256 `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`;
- unoserver `3.7` PyPI wheel;
- wheel SHA-256 `fc44e6808071c9d2957e705ecf1742cea8a582aa5d5cc23babf36bb332ec6e8e`.

Focused branch/workflow:

- branch `pdf-tunner/libreoffice-uno-candidate`;
- `.github/workflows/pdf-tunner-libreoffice-uno-candidate.yml`;
- `.github/scripts/prepare-libreoffice-uno-candidate.ps1`;
- `.github/scripts/validate-libreoffice-uno-candidate.ps1`.

Candidate design:

1. download official MSI and enforce SHA-256;
2. administrative-extract the MSI without installing LibreOffice;
3. copy the suite to candidate `tools/libreoffice`;
4. resolve/download exact PyPI wheel and enforce SHA-256;
5. extract unoserver under `tools/unoserver`;
6. real DOCX -> PDF through package-local `soffice` with profile and TEMP/TMP in candidate `data/`;
7. move the candidate to a path containing spaces and repeat the real conversion;
8. require LibreOffice's Windows `program/python.exe` to import `uno` plus pinned unoserver;
9. start a real unoserver at `127.0.0.1:2003`, UNO port `2004`, package-local profile/temp;
10. execute a real unoconvert DOCX -> PDF after relocation;
11. emit compact provenance/feasibility evidence.

Focused green is not primary acceptance. After focused proof, integrate only the proven mechanism into `pdf-tunner/windows-portable-v1`, including runtime launch/cleanup semantics as needed, and rerun the complete primary workflow.



### LibreOffice candidate diagnostic history

- Run `33252792182` (#1), job `99101259425`: failed in the PowerShell harness after successful official MSI download/hash validation/admin extraction because `$LASTEXITCODE` was read under `Set-StrictMode` after GUI-subsystem `soffice.exe`; no product conclusion.
- Run `33253632305` (#2), job `99103473257`: candidate preparation succeeded and real DOCX -> PDF succeeded in the original location with package-local LibreOffice plus sandbox-local profile/TEMP/TMP. Relocated conversion failed only because the harness still used `soffice.exe` for a Windows headless CLI operation; it returned 0 but produced no PDF. LibreOffice's official Windows CLI guidance uses `soffice.com` for command-line/headless operations. The next revision must retain the path-with-spaces relocation gate and use package-local `soffice.com` for direct CLI conversions, with `.exe` only as fallback when `.com` is absent.
- Run `33254174353` (#3), job `99104896585`: `soffice.com` was used as intended, original-location DOCX -> PDF passed again, but relocated conversion still returned success without a PDF. Next diagnostic/fix must preserve the relocation gate and explicitly detect/terminate only package-local LibreOffice residual processes (`soffice.bin`/related children) before moving the tree; record counts/process identities in candidate evidence and verify zero package-local LibreOffice processes remain before relocation.


## Primary acceptance contract

A dependency moves to accepted only when the complete primary workflow is green with every earlier accepted gate still enabled. Record exact source/version/hash plus commit, Run/job and artifact/digest where relevant.

A standalone focused workflow is diagnostic/candidate evidence only. Runner-installed software must not satisfy package validation.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. LibreOffice focused proof and primary integration;
2. UNO/`unoconvert` primary integration with deterministic startup/shutdown and sandboxed profile/temp;
3. Poppler: `pdftohtml`, `pdfinfo`, `pdfimages`;
4. consolidate portable Python dependency lock;
5. NumPy;
6. OpenCV;
7. WeasyPrint;
8. Calibre/`ebook-convert`;
9. `unpaper`;
10. `pngquant`;
11. conversion fonts;
12. explicit VeraPDF E2E;
13. investigate/build/package `jbig2enc` if viable;
14. viable portable RAR/CBR or concrete documented limitation;
15. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Office -> PDF; supported PDF -> Office; OCR; HTML/URL -> PDF; Poppler; WeasyPrint; Calibre/EPUB; Python/NumPy/OpenCV; regressions of qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF; `pngquant`/`unpaper`; representative Stirling API families; explicit proof that host tools are not satisfying tests.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final sandbox/portability/state/process audit;
4. remove development-only push/status/focused mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening PR #1;
8. publish clean v1 ZIP only after all gates;
9. manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-08-29

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python; OCRmyPDF. Post-OCR primary Run #78 is green.

Active work: focused Windows LibreOffice 26.2.5 + unoserver 3.7 feasibility on `pdf-tunner/libreoffice-uno-candidate`.

Next after candidate proof: integrate the proven LibreOffice/UNO mechanism into the primary portable package without regressing the accepted sandbox boundary, then move to Poppler.
