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
12. Do not publish a final Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete.

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
- LibreOffice -> `<portable>/tools/libreoffice`; native source-compatible `unoconvert.exe` -> `<portable>/tools/bin`; LibreOffice child temp -> `<portable>/data/tmp/libreoffice`; transient per-invocation shim profiles -> `<portable>/p/` and must be empty after each conversion;
- Poppler -> `<portable>/tools/poppler`, executables under `Library/bin`;
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

- `10.07.1` Win64;
- SHA-256 `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`;
- acceptance Run `33104114920` (#68), job `98629258424`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004`.

### Tesseract — accepted

- release `5.5.3`, Windows CLI `5.5.3.20260724`;
- installer SHA-256 `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`;
- `tessdata_fast` commit `87416418657359cb625c412a48b6e1d6d41c29bd`;
- acceptance Run `33122172947` (#70), job `98691480028`, commit `52429eb7812e8615ee39aab695641d495798c1ba`; artifact `9667429758`, digest `sha256:12943b1b38ac7660156667acbaf5a0d3ccae189d0f9d28be97fe32b0db8326aa`.

### Python 3.12.14 + OCRmyPDF 17.10.0 — accepted

Pins:

- Python `3.12.14` x64 from `astral-sh/python-build-standalone` release `20260825`;
- archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` PyPI wheel;
- wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

`.github/scripts/ocrmypdf-launcher.rs` builds a native relative launcher under `tools/python/ocrmypdf.exe`, executing sibling `python.exe -m ocrmypdf` and localizing OCRmyPDF temp/Python cache to `data/`.

Primary acceptance: Run **`33201568275` (#77)**, job **`98952028665`**, commit **`54802c15427673c0e95738195947ab76239d6e31`**, complete success with all earlier gates enabled.

Run #77 proved exact pins/hashes, AMD64 Python, isolated package-only resolution, clean `pip check`, real searchable-PDF OCR, searchable-text extraction, package-local temp/cache, relocation to a path containing spaces, real backend acceptance of `ocrmypdf`, final layout validation, ZIP creation and SHA-256.

Artifact **`9698621272`**, name `PDF_Tunner-Windows-x64-Portable-bootstrap`, Actions digest **`sha256:68f69bb0d4ed6b731aefee82abff3eba7b01d18c5b270051e2e546337cd6a164`**. CI evidence only; not a final Release.

The temporary focused OCRmyPDF workflow is retired after this primary acceptance; the permanent prepare/validate/launcher scripts remain part of the primary workflow.

### LibreOffice 26.2.5 + native `unoconvert` — accepted

Do not restart this block from the old wrapper or from `unoserver`. The only architecture is the Stirling Tauri desktop plus bundled Windows LibreOffice and a native package-relative compatibility shim:

- pinned payload: LibreOffice Windows x86-64 `26.2.5` from `https://download.documentfoundation.org/libreoffice/stable/26.2.5/win/x86_64/LibreOffice_26.2.5_Win_x86-64.msi`;
- pinned MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`;
- preparation: `.github/scripts/prepare-libreoffice.ps1` verifies the MSI and uses `msiexec /a` administrative extraction only — never a runner installation — then stages `<portable>/tools/libreoffice/`;
- required payload paths: `tools/libreoffice/program/soffice.com`, `tools/libreoffice/program/soffice.exe`, and `tools/bin/unoconvert.exe`;
- shim source: `.github/scripts/unoconvert-launcher.rs`; it resolves the portable root from its own executable, uses `soffice.com` with `soffice.exe` fallback, provides `--version`, accepts split/equal `--convert-to` and `--input-filter`, ignores split/equal Stirling endpoint metadata (`--host`, `--port`, `--host-location`, `--protocol`), translates to `--infilter`, uses a unique `<portable>/p/` profile plus `<portable>/data/tmp/libreoffice/`, returns the exact requested output path, and removes its profile;
- permanent validator: `.github/scripts/validate-libreoffice.ps1`; it verifies provenance/hash/AMD64, isolated `where` resolution, direct and shim conversions, normal relocation with spaces, package-local state and no package LibreOffice processes. It also owns the actual backend API proof when given the backend URL/log root.

Stirling 2.14.3 facts that must remain preserved: `RuntimePathConfig` defaults to literal `soffice` and `unoconvert`; `ExternalAppDepConfig` probes and groups them independently as `LibreOffice` and `Unoconvert`; `ConvertOfficeController` first calls `unoconvert --convert-to pdf INPUT OUTPUT`; `PDFToFile` first calls `unoconvert --convert-to FORMAT --input-filter=writer_pdf_import INPUT OUTPUT`; and `ProcessExecutor` can inject the four UNO endpoint options. The primary validator therefore requires successful real routes `POST /api/v1/convert/file/pdf` and `POST /api/v1/convert/pdf/word` with field `fileInput` (and `outputFormat=docx` for the latter), backend logs with neither dependency/group disabled, and an actual `Running command: unoconvert` record. The Tauri child is started with package-only PATH entries plus Windows system directories, so a runner installation cannot satisfy this proof.

Candidate history is not product input: `pdf-tunner/libreoffice-uno-candidate` at `8dea43f511771f5483f6b038067cfd39ec7f68e3` / focused Run #13 (`33272788391`, job `99154179041`) established that the shim works, but it is not acceptance. Only its final prepare/shim/validator design was consolidated. Historical diagnostic scripts/workflow from candidate runs #1–#12 are deliberately absent from the primary branch. The documented limitation is LibreOffice sensitivity to extreme Windows path lengths; test and accept ordinary relocation paths containing spaces, not synthetic extreme paths.

### Poppler 26.02.0 — primary regression passed; formal acceptance pending post-documentation regression

The candidate pins `oschwartz10612/poppler-windows` release `v26.02.0-0`, asset `Release-26.02.0-0.zip`, SHA-256 `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`. This is a third-party Windows x64 distribution of Poppler upstream and provenance must identify both the upstream project and the binary distributor.

Permanent scripts are `.github/scripts/prepare-poppler.ps1` and `.github/scripts/validate-poppler.ps1`. The payload is staged at `tools/poppler/`; required binaries are `Library/bin/pdftohtml.exe`, `pdfinfo.exe` and `pdfimages.exe`. Preparation must hash the downloaded archive before extraction and persist per-executable hashes without retaining the archive.

The validator must preserve these gates: AMD64 identity; exact archive and executable hashes; isolated package-only `where` resolution; real `pdfinfo`, `pdfimages -list`, `pdftohtml -c`, and `pdftohtml -s -noframes -c` operations against a generated text-and-image PDF; relocation with spaces; final cleanup; and the actual Stirling route `POST /api/v1/convert/pdf/html` with backend logs proving the `Pdftohtml` group was not disabled and `Running command: pdftohtml` occurred.

Complete primary Run #84 (`33502880719`), job `99840040906`, commit `745d87e86096485927a72a0586c4ec5cb969d8c8`, passed every previous gate and every Poppler gate. Packaged executable SHA-256 values: `pdftohtml.exe` `9fb2802fe026a3ce9967229738e98861b20619b25829f273d3656a05656b0b2f`; `pdfinfo.exe` `34040ff62bef73d6847a7b443457ac7fe216eb331bfbeadec62ae555618b2aae`; `pdfimages.exe` `22ce0c5fc3fac7c19ae526bd3bd3f6fa90592699bb867bf0b62676c72a890d0a`. The generated ZIP was `1,463,915,169` bytes, SHA-256 `5146303DEC1D4D37E88217D9DB32422411198944C95182693CF0F38909120FA0`, and was not uploaded. Artifact `9799390618`, `PDF_Tunner-Windows-x64-CI-evidence`, is `1,727` bytes with Actions digest `sha256:a77cd50cab23248a968526022548e3df2468674e5cc565275a8146bb7a42e4e3`, expires 2026-09-08, and contains only package evidence, ZIP checksum, layout summary and Poppler provenance/checksums. Formal acceptance requires one post-documentation complete primary regression. Post-documentation Run #85 (`33506142322`), job `99850534886`, failed before any Poppler or packaging gate because Maven Central returned HTTP 429 during Gradle dependency resolution. Treat it as a transient upstream infrastructure failure, not functional evidence; the workflow correction retries only detected HTTP 429 failures within the same runner and keeps Actions caches disabled.

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency moves to accepted only when the **complete primary workflow** is green with every earlier accepted gate enabled. Record commit SHA, Run/number, job ID, exact source/version/hash and artifact/digest when relevant.

A standalone candidate workflow or `--version` alone is not acceptance. Require real operation and isolated package-first PATH/environment wherever practical.

## CI artifact storage policy

The primary workflow must always build the portable ZIP and execute all acceptance gates. It records the ZIP SHA-256, size, package provenance and layout summary, then uploads only that lightweight CI evidence by default; it must not upload the portable ZIP itself on ordinary runs. Failure diagnostics are text-only, hard-capped at 2 MB and retained for 3 days.

The primary workflow must keep npm/Gradle Actions caches disabled; ordinary runs may retain only the bounded text diagnostics and lightweight evidence artifact described above. Desktop preparation may retry a detected Maven Central HTTP 429 up to three attempts with 45/90-second backoff inside the same runner; do not persist its Gradle state as an Actions cache. This policy saves GitHub Actions storage without weakening validation. A large artifact is exceptional, requires a concrete evidence need plus quota/retention review, and must never be retained merely as an archive. The final portable ZIP is a GitHub Release asset only after final v1 acceptance; do not create a Release early.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. Poppler including `pdftohtml`, `pdfinfo`, `pdfimages`;
2. consolidate portable Python dependency lock;
3. NumPy;
4. OpenCV;
5. WeasyPrint;
6. Calibre/`ebook-convert`;
7. `unpaper`;
8. `pngquant`;
9. conversion fonts;
10. explicit VeraPDF E2E;
11. investigate/build/package `jbig2enc` if viable;
12. viable portable RAR/CBR or concrete documented limitation;
13. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Office -> PDF; supported PDF -> Office; HTML/URL -> PDF; WeasyPrint; Poppler; Calibre/EPUB; Python/NumPy/OpenCV; regressions across accepted qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF; `pngquant`/`unpaper`; RAR/CBR and jbig2enc if integrated; representative Stirling API families; explicit proof runner software is not satisfying package tests.

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

## Current handoff — 2026-09-01

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python 3.12.14 + OCRmyPDF 17.10.0; LibreOffice 26.2.5 + native `unoconvert`.

Latest green primary regression: **Run #84** (`33502880719`), job `99840040906`, commit `745d87e86096485927a72a0586c4ec5cb969d8c8`; ZIP SHA-256 `5146303DEC1D4D37E88217D9DB32422411198944C95182693CF0F38909120FA0`, size `1,463,915,169` bytes; evidence artifact `9799390618` (`1,727` bytes), Actions digest `sha256:a77cd50cab23248a968526022548e3df2468674e5cc565275a8146bb7a42e4e3`, expires 2026-09-08.

Run #84 passed all earlier gates plus pinned Poppler 26.02.0 archive/executable hashes, AMD64 identity, isolated package-only resolution, real `pdfinfo`, `pdfimages` and both Stirling `pdftohtml` forms, relocation with spaces, final cleanup, and the real Stirling PDF→HTML backend route. The ZIP was generated and validated but not uploaded; only the lightweight evidence artifact was retained.

Poppler formal acceptance is pending exactly one successful post-documentation complete primary regression. Run #85 (`33506142322`), job `99850534886`, failed during desktop preparation on Maven Central HTTP 429 before any Poppler gate. The corrected workflow adds bounded same-runner retries without persistent caches. Do not begin the next dependency block until the corrected regression is green; the broader A/B/C roadmap remains mandatory.

## Compact changelog

- **2026-08-21–23:** real fork/base confirmed; Stirling Tauri + JLink architecture selected; portable state containment and two-launch window-state proof established.
- **2026-08-27:** Fixed WebView2 accepted #62; qpdf #66; ImageMagick #67; Ghostscript #68; Tesseract #70.
- **2026-08-28:** OCRmyPDF candidate built around pinned relocatable Python standalone + native relative launcher + real searchable-PDF/relocation validation.
- **2026-08-28:** focused OCRmyPDF Run #5 passed fully; primary Run #76 reconfirmed the prior baseline.
- **2026-08-28:** primary Run #77 passed with Python/OCRmyPDF integrated, real OCR, relocation, backend dependency acceptance, final ZIP and SHA-256. Python/OCRmyPDF accepted.
- **2026-08-29:** temporary OCRmyPDF candidate workflow retired; primary Run #78 reconfirmed the accepted baseline.
- **2026-08-29:** LibreOffice 26.2.5 focused candidate Run #13 passed isolated extraction/shim/relocation probes.
- **2026-09-01:** primary Run #82 passed all gates with LibreOffice/unoconvert plus real backend conversions; retained CI evidence is 958 bytes.
- **2026-09-01:** post-documentation primary Run #83 passed every gate; ZIP SHA-256 and a 957-byte evidence artifact were retained. LibreOffice 26.2.5 + native `unoconvert` accepted; Poppler became the active block.
- **2026-09-01:** Poppler 26.02.0 Windows x64 candidate integrated with pinned archive hash, isolated direct/relocation gates and real Stirling PDF→HTML backend proof.
- **2026-09-01:** complete primary Run #84 passed every previous and Poppler gate; generated ZIP SHA-256 `5146303DEC1D4D37E88217D9DB32422411198944C95182693CF0F38909120FA0`; retained evidence is 1,727 bytes. Formal acceptance pending the post-documentation regression.
- **2026-09-01:** post-documentation Run #85 failed before functional gates on Maven Central HTTP 429; added bounded same-runner retry/backoff while keeping Actions caches disabled.
