# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository. These rules override generic repository cleanup conventions when those conventions would make the Stirling fork harder to compare, synchronize or validate.

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

1. Preserve Stirling's root structure; do not reorganize the fork into generic `Archive/`, `Source/` or `Validation/` roots.
2. Keep `main` clean: no generated builds, logs, abandoned experiments, one-shot triggers or temporary scripts.
3. Preserve upstream behavior unless the user requests removal or the functionality is specifically outside the target.
4. Compilation alone is never validation. Validate the assembled portable app and real operations.
5. Never archive failed/intermediate builds as release history.
6. Keep SHA-256/provenance and exact dependency identity reproducible.
7. **Every PDF_Tunner-specific change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
8. Heavy repeated CI must use branch/workflow-specific `concurrency` with `cancel-in-progress: true`; obsolete runs must not pile up.
9. During active development use at most one automatic trigger per heavy workflow unless duplicate events are technically necessary and deduplicated.
10. Development-only workflows/status bridges/triggers must be removed when their phase is finished and before final `main`.
11. Do not reopen old PR #1 as the v1 release integration vehicle.
12. Do not publish a final Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete.
13. Licensing is not the center of this project; mention it only for concrete technical/distribution constraints.

## Continuity protocol

Before writes in a resumed conversation:

1. recover the most recent relevant PDF_Tunner handoff/conversation context;
2. read the current project prompt/rules, README and AGENTS;
3. verify live branch HEAD, latest primary Actions run, PR state and Release state;
4. explicitly carry **accepted/closed**, **active candidate**, **next block** and **broader roadmap**;
5. never treat one immediate next task as the only remaining work;
6. at each accepted milestone record commit, Run/job, artifact/digest where relevant, next candidate and remaining roadmap in README + AGENTS;
7. before final Release re-audit against the full original PDF_Tunner objective.

## Architecture and portable boundary

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`. Do not restore the old `PDF_Tunner_Legacy` .NET/WebView2 launcher architecture.

The pinned desktop build uses Java 25/JLink and Stirling's existing Tauri lifecycle. Preserve upstream single-instance, file-opening, drag/drop, dynamic backend-port discovery and backend cleanup unless a portable-specific defect is demonstrated.

Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable.

Do **not** globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before Tauri/WebView2 initializes. Use component-specific localization:

- `PDF_TUNNER_PORTABLE_ROOT` -> executable directory;
- Stirling app data -> `<portable>/data`;
- Java `java.io.tmpdir` -> `<portable>/data/tmp` through `JAVA_TOOL_OPTIONS`;
- WebView2 user data -> `<portable>/data/webview2`;
- Tauri logs/store/window-state/http cookies -> `<portable>/data/tauri/...`;
- ImageMagick config -> `<portable>/tools/imagemagick`, temp -> `<portable>/data/tmp/imagemagick`;
- Ghostscript -> package-first `<portable>/tools/ghostscript/bin`;
- Tesseract -> package-first `<portable>/tools/tesseract`, `TESSDATA_PREFIX=<portable>/tools/tesseract/tessdata`;
- Python/OCRmyPDF -> `<portable>/tools/python`; OCRmyPDF child temp -> `<portable>/data/tmp/ocrmypdf`; Python cache -> `<portable>/data/python-cache`;
- Calibre config -> `<portable>/data/calibre` when packaged;
- skip `pdf-tunner://` deep-link registration in portable mode.

The Windows keyring/Credential Manager may remain authentication's first path and is not claimed to be package-contained; Tauri Store fallback is package-local.

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

`ExternalAppDepConfig` disables the OCRmyPDF endpoint group when the configured `ocrmypdf` command cannot be resolved. Primary acceptance of OCRmyPDF therefore requires both an isolated real OCR operation and proof that the real PDF_Tunner backend does not log `Missing dependency: ocrmypdf` / disable the OCRmyPDF group.

## Tool layout strategy

Package under one `tools/` subtree per dependency. Tauri prepends, when present:

- `tools/bin`;
- `tools/python` and `tools/python/Scripts`;
- `tools/libreoffice/program`;
- `tools/tesseract`;
- `tools/ghostscript/bin`;
- `tools/qpdf/bin`;
- `tools/poppler/Library/bin`;
- `tools/imagemagick`;
- `tools/calibre`;
- `tools/pngquant`;
- `tools/unpaper`;
- `tools/rar`;
- `tools/jbig2enc`.

If Windows executable naming differs from Stirling's literal probe, provide a deterministic package-local alias/shim only after proving the exact probe. Never count runner-installed software as package evidence.

## Accepted layers and evidence

### Native portable/Tauri containment — accepted

Real packaged startup/backend health, Java temp localization, WebView2 profile localization, package-local Tauri stores/logs/http cookies, protocol containment, normal process-tree cleanup and two-launch window-state persistence are accepted. Run `32825188381` is the key consolidated AppData/window-state proof.

### Fixed WebView2 — accepted

- `151.0.4129.101` x64;
- official CAB SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`;
- acceptance Run `33058462619` (#62), job `98471041328`, commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4`.

### qpdf — accepted

- `12.4.0` MinGW64;
- SHA-256 `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`;
- acceptance Run `33086404875` (#66), job `98567113737`, commit `413994c9ea368b5144a26686afef6011eba8de59`.

### ImageMagick — accepted

- `7.1.2-30` portable Q16 x64;
- SHA-256 `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`;
- acceptance Run `33092698357` (#67), job `98589465377`, commit `d1801e8569a23a762035a39dc7295de0f19e6115`.

### Ghostscript — accepted

- `10.07.1` Win64, official `gs10071w64.exe`;
- SHA-256 `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`;
- NSIS is archive-extracted, never installed; package-local byte-identical `gs.exe` satisfies Stirling's literal probe;
- acceptance Run `33104114920` (#68), job `98629258424`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004`.

### Tesseract — accepted

- release `5.5.3`, Windows CLI `5.5.3.20260724`;
- official Win64 installer SHA-256 `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`;
- `tessdata_fast` commit `87416418657359cb625c412a48b6e1d6d41c29bd`;
- models: `eng` blob `bbef4675053b5b468cdb477053e28b1c698ba08e`, `spa` `72e901f13ca52cfe34cf239a368b9ed3c0ddaf26`, `osd` `527457ca8f8fe1fda7c2f88bce3c0e4be12be9d0`;
- validation includes isolated package-first PATH, real English/Spanish OCR, OSD and Stirling backend package-local tessdata acceptance;
- acceptance Run `33122172947` (#70), job `98691480028`, commit `52429eb7812e8615ee39aab695641d495798c1ba`; artifact `9667429758`, digest `sha256:12943b1b38ac7660156667acbaf5a0d3ccae189d0f9d28be97fe32b0db8326aa`.

Latest pre-OCRmyPDF primary baseline: Run `33169895113` (#76), job `98844184305`, commit `9f0dcb4cb35cb73a1ceadf2ebe105ec23c5fd3c8`, complete success.

## Active integration: Python 3.12.14 + OCRmyPDF 17.10.0

Pins:

- Python `3.12.14` x64;
- `astral-sh/python-build-standalone` release `20260825`, `x86_64-pc-windows-msvc-install_only_stripped`;
- archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` PyPI wheel;
- wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

The normal pip-generated Windows launcher is removed. `.github/scripts/ocrmypdf-launcher.rs` builds a native relative launcher under `tools/python/ocrmypdf.exe`, executing sibling `python.exe -m ocrmypdf` and localizing OCRmyPDF temp/Python cache to `data/`.

Permanent scripts:

- `.github/scripts/prepare-ocrmypdf.ps1` — download/hash/extract Python standalone, verify/install exact OCRmyPDF, compile relative launcher, run `pip check`, write provenance/hashes/canonical dependency inventory;
- `.github/scripts/validate-ocrmypdf.ps1` — PE/version/provenance checks, isolated PATH proof, real OCR searchable-text check and optional relocation proof;
- `.github/scripts/ocrmypdf-launcher.rs` — native relative launcher.

Focused Run `33169895080` (#5), job `98844184266`, commit `9f0dcb4cb35cb73a1ceadf2ebe105ec23c5fd3c8`, is green and proves exact versions/hashes, AMD64, package-only command resolution, clean `pip check`, real searchable-PDF OCR, `pdfminer-six` searchable-text extraction, package-local temp/cache and a second complete OCR after relocation to a path containing spaces.

Runs #1, #2 and #4 remain diagnostic failure evidence only: they exposed and led to fixes for dependency inventory normalization, synthetic image DPI and alpha-channel fixture encoding respectively.

**Focused green is not acceptance.** The active revision promotes the same Python/OCRmyPDF layer into the primary workflow. Accept only when the complete primary workflow is green with all previous gates enabled, backend dependency probing accepts `ocrmypdf`, the real OCR/relocation checks pass from the package, final layout contains the Python/OCRmyPDF provenance files, and the final ZIP/SHA is produced.

After primary acceptance, remove `.github/workflows/pdf-tunner-ocrmypdf-candidate.yml` when it is no longer needed and document that removal in README + AGENTS in the same commit.

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency moves to accepted only when the **complete primary workflow** is green with every earlier accepted gate still enabled. Record commit SHA, Run/number, job ID, exact source/version/hash and artifact/digest when relevant.

A green standalone preparation/focused workflow is not acceptance. `--version` alone is not acceptance. Require real operation and isolated package-first PATH/environment wherever technically practical.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. complete primary OCRmyPDF + Python acceptance and retire the focused gate when safe;
2. LibreOffice;
3. UNO/`unoconvert` or source-compatible portable alternative;
4. Poppler including `pdftohtml`, `pdfinfo`, `pdfimages`;
5. consolidate portable Python dependency lock;
6. NumPy;
7. OpenCV;
8. WeasyPrint;
9. Calibre/`ebook-convert`;
10. `unpaper`;
11. `pngquant`;
12. conversion fonts;
13. explicit VeraPDF E2E;
14. investigate/build/package `jbig2enc` if viable;
15. viable portable RAR/CBR or concrete documented limitation;
16. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

OCRmyPDF E2E; Office -> PDF; supported PDF -> Office; HTML/URL -> PDF; WeasyPrint; Poppler; Calibre/EPUB; Python/NumPy/OpenCV; qpdf/Ghostscript/ImageMagick/Tesseract regressions; `pngquant`/`unpaper`; RAR/CBR and jbig2enc if integrated; representative Stirling API families; explicit proof runner software is not satisfying package tests.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove development push/status/focused diagnostic mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening PR #1;
8. publish clean v1 ZIP only when all gates are complete;
9. manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-08-28

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract.

Latest fully green primary baseline: **Run #76** on commit `9f0dcb4cb35cb73a1ceadf2ebe105ec23c5fd3c8`.

Focused OCRmyPDF/Python gate: **Run #5 green** on the same commit, including real searchable OCR and relocation.

Active work: promote Python/OCRmyPDF into the complete primary workflow and require the real backend to accept the `ocrmypdf` dependency. OCRmyPDF is not accepted until that primary run is green.

Next external block only after OCRmyPDF acceptance: LibreOffice/UNO, while the broader A/B/C roadmap remains mandatory.

## Compact changelog

- **2026-08-21–23:** real fork/base confirmed; Stirling Tauri + JLink architecture selected; portable state containment and two-launch window-state proof established.
- **2026-08-27:** Fixed WebView2 accepted #62; qpdf #66; ImageMagick #67; Ghostscript #68; Tesseract #70.
- **2026-08-28:** OCRmyPDF candidate built around pinned relocatable Python standalone + native relative launcher + real searchable-PDF/relocation validation.
- **2026-08-28:** focused Runs #1/#2/#4 diagnosed and corrected package inventory, fixture DPI and alpha-channel test issues without changing Stirling behavior.
- **2026-08-28:** focused OCRmyPDF Run #5 passed fully; primary Run #76 concurrently reconfirmed the previous accepted baseline. Primary integration is now the active gate.
