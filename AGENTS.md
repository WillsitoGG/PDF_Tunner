# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository. These rules override generic cleanup conventions when those conventions would make the Stirling fork harder to compare, synchronize or validate.

## Project identity and target

PDF_Tunner is the real GitHub fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

Target:

- Windows 10/11 x64;
- portable ZIP: extract and run without machine-installed Java/Python/LibreOffice/Tesseract/Ghostscript/Calibre/etc. when those dependencies can technically be bundled;
- application/binary name `PDF_Tunner`;
- retain Stirling functionality except functionality specifically belonging to Enterprise/SaaS offerings;
- keep configuration, caches, logs, temporary files and runtime state inside the portable tree as far as the underlying Windows APIs allow;
- remain straightforward to diff/rebase/update from upstream;
- validate real assembled operations, not compilation or `--version` output alone.

## Pinned starting point

- Upstream: `Stirling-Tools/Stirling-PDF`
- Version: `2.14.3`
- Initial snapshot commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Java: 25
- Development branch: `pdf-tunner/windows-portable-v1`
- `main` remains the clean upstream base until the v1 release gates are complete.
- No final PDF_Tunner v1 Release exists yet.

Record any future upstream update here and in README before treating it as the new base.

## Mandatory repository rules

1. Preserve Stirling's root structure. Do not reorganize the fork into generic root `Archive/`, `Source/` or `Validation/` trees.
2. Keep `main` clean: no build outputs, logs, abandoned experiments, one-shot triggers or temporary scripts.
3. Prefer small, localized downstream deltas.
4. Preserve upstream behavior unless the user explicitly requests removal or the functionality is specifically outside the PDF_Tunner target.
5. Compilation alone is never validation. Test the assembled portable application and relevant operations.
6. Never archive failed/intermediate builds as release history.
7. Preserve historical git tags; only final published packages count as Release history.
8. SHA-256/provenance belongs in repository validation records rather than miscellaneous Release assets unless a final packaging decision says otherwise.
9. **Every PDF_Tunner-specific change must modify both `README.md` and `AGENTS.md` in the same commit.**
10. Do not make licensing the center of technical work. Mention it only when it creates a concrete implementation/distribution constraint.
11. Heavy repeated CI must use branch/workflow-specific `concurrency` with `cancel-in-progress: true`; obsolete portable runs must not pile up.
12. During active downstream development use at most one automatic trigger for the heavy portable workflow unless duplicate events are technically necessary and deduplicated.
13. The development Commit Status bridge may expose push-run IDs for connected tooling but must not add another workflow/job, commit repository state or remain in the final `main` configuration.
14. Keep the old PR #1 closed. Do not reuse/reopen it as the final release integration vehicle.
15. Do not create a final GitHub Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete.

## Continuity protocol — mandatory before resumed work

A resumed PDF_Tunner conversation must not begin by simply doing the next remembered task. Before repository writes:

1. Recover the **two most recent relevant PDF_Tunner conversations/work handoffs**.
2. Read the current project prompt/rules plus `README.md` and `AGENTS.md`.
3. Verify live GitHub state: development branch HEAD, most recent primary Actions run, PR state and Releases.
4. Reconstruct and carry four states explicitly:
   - **accepted/closed**;
   - **active candidate**;
   - **next block**;
   - **broader remaining roadmap**.
5. Never treat “the next task is X” as meaning X is the only remaining work.
6. At an accepted milestone record commit, Run/job, artifact/digest where relevant, the next candidate and the broader roadmap in README + AGENTS.
7. Before final Release, re-audit against the **full original PDF_Tunner objective**, not merely the most recently completed dependency.

This protocol exists because continuity was previously lost when a resumed conversation narrowed the remaining project to one dependency while a much larger agreed backlog still existed.

## Architecture decision

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`.

Do not restore the old `PDF_Tunner_Legacy` architecture in which a separate .NET WinForms/WebView2 launcher starts a Stirling JAR. Legacy is reference material only.

Retain useful portable principles:

- component-specific data/profile redirection;
- bundled Java;
- loopback-only backend;
- readiness/health checks;
- process-tree cleanup;
- reproducible ZIP + SHA-256;
- explicit dependency source/version/hash/provenance checks.

Current upstream Tauri already owns single-instance handling, file opening, drag/drop, WebView lifecycle, dynamic backend-port discovery and backend cleanup. Preserve those mechanisms unless a portable-specific defect is demonstrated.

## Desktop/JRE facts

`.taskfiles/desktop.yml` is the authoritative desktop build path. At the pinned base it:

- builds the desktop backend boot JAR;
- bundles Windows x64 JPDFium natives;
- builds a Java 25 JRE with JLink;
- includes `jdk.dynalink` for VeraPDF;
- includes `jdk.crypto.mscapi` on Windows;
- stages the JAR in `frontend/editor/src-tauri/libs`;
- stages the JRE in `frontend/editor/src-tauri/runtime/jre`;
- exposes Tauri/Cargo tests via `task desktop:test`.

The official desktop task currently sets `DISABLE_ADDITIONAL_FEATURES=true`. Treat core/proprietary/SaaS as a source-backed feature-partition question; do not change flavor merely to make missing external tools appear supported.

## Portable boundary

Portable mode is enabled by marker file `PDF_TUNNER_PORTABLE` beside the executable.

**Do not globally replace Windows `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before Tauri/WebView2 initializes.** CI proved that strategy can kill startup before Tauri/backend logging.

Use component-specific localization:

- `PDF_TUNNER_PORTABLE_ROOT` -> executable directory;
- Stirling `app_data_dir()` -> `<portable>/data`;
- provisioning -> `<portable>/data/provisioning`;
- Tauri-side logs -> `<portable>/data/logs/`;
- Java `java.io.tmpdir` -> `<portable>/data/tmp` through `JAVA_TOOL_OPTIONS`;
- WebView2 user data -> `<portable>/data/webview2`;
- desktop connection/token Store -> `<portable>/data/tauri/store/`;
- portable window-state -> `<portable>/data/tauri/window-state/.window-state.json`;
- `tauri-plugin-http` cookies -> `<portable>/data/tauri/http/.cookies`;
- `CALIBRE_CONFIG_DIRECTORY` -> `<portable>/data/calibre` when Calibre is packaged;
- ImageMagick `MAGICK_HOME`/`MAGICK_CONFIGURE_PATH` -> `<portable>/tools/imagemagick` and temp -> `<portable>/data/tmp/imagemagick`;
- Ghostscript -> package-first `<portable>/tools/ghostscript/bin`;
- Tesseract -> package-first `<portable>/tools/tesseract` and `TESSDATA_PREFIX=<portable>/tools/tesseract/tessdata`;
- packaged tool directories are prepended to PATH only when present;
- skip `pdf-tunner://` deep-link registration in portable mode.

The Windows keyring/Credential Manager remains authentication's first path and is not claimed to be package-contained; the Tauri Store fallback is package-local.

### Portable window-state

Keep official `tauri-plugin-window-state` behavior outside portable mode. In portable mode use the localized implementation under `data/tauri/window-state/.window-state.json` because the official plugin path is tied to Tauri `app_config_dir()`.

The implementation must preserve upstream semantics (`width`, `height`, `x`, `y`, `prev_x`, `prev_y`, `maximized`, `visible`, `decorated`, `fullscreen`), operate directly on Tauri's native `Window<R>` in `on_window_ready`, restore monitor-safe geometry in upstream-compatible order, save before terminal portable cleanup/exit, and avoid duplicate listeners.

Run `32825188381` is the accepted AppData/window-state containment proof: deliberate geometry was persisted package-locally and restored on a second launch while tracked host identifier state remained empty/contained.

## Branding/config

Prefer additive downstream config over rewriting upstream config wholesale.

Current overlay:

`frontend/editor/src-tauri/tauri.pdf-tunner.conf.json`

It supplies PDF_Tunner product/binary/window identity and prevents the downstream executable from following Stirling's upstream updater endpoint. Until PDF_Tunner has its own signed updater metadata, in-app updating is not considered an available PDF_Tunner feature.

A final branding audit is still required before Release.

## External dependency source of truth

Do not invent dependency lists. For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- relevant controller/service source for each feature being validated.

Direct runtime probes include:

| Feature group | Runtime probe |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` (minimum 58) |
| Poppler/PDF HTML | `pdftohtml` |
| UNO conversion | `unoconvert` |
| qpdf | `qpdf` (minimum 12) |
| Tesseract | `tesseract` |
| CBR/RAR | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |

The pinned source/toolchain also exposes Poppler helpers such as `pdfinfo`/`pdfimages` and confirms `unpaper`, `pngquant`, LibreOffice/UNO infrastructure, Tesseract languages + OSD, Python, WeasyPrint, `pdf2image`, OpenCV headless, OCRmyPDF, `unoserver`/Unoconvert infrastructure and conversion fonts.

For every Windows dependency record exact version, official source, immutable hash/ref, normalized portable layout and real validation here and in README.

## Toolchain packaging strategy

Use `tools/` with one subdirectory per upstream tool. Expected PATH candidates include:

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

If a Windows executable name differs from what Stirling probes, provide a deterministic package-local alias/shim only after proving the exact probe works. Never count runner-installed software as package evidence.

## Accepted layers

### Native portable/Tauri containment — accepted

Accepted evidence includes real packaged startup/backend health, Java temp localization, WebView2 profile localization, package-local Tauri stores/logs/http cookie state, protocol-registry containment, process-tree cleanup and the two-launch window-state proof. Run `32825188381` is the key consolidated AppData/window-state acceptance run.

### Fixed WebView2 — accepted

- `151.0.4129.101` x64.
- Official pinned CAB SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`.
- Package: `runtime/webview2/fixed/`.
- Acceptance: primary Run `33058462619` (#62), job `98471041328`, commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4`.
- Keep package-local browser executable/profile and required AppContainer ACL proof; no Evergreen/system fallback for acceptance.

### qpdf — accepted

- Version `12.4.0` MinGW64.
- Asset `qpdf-12.4.0-mingw64.zip`.
- SHA-256 `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`.
- Package `tools/qpdf/`.
- Mandatory validation: archive/exe provenance, isolated package-first PATH, generated structurally valid PDF `--check`, exact page count and Stirling minimum-version acceptance.
- Acceptance: Run `33086404875` (#66), job `98567113737`, commit `413994c9ea368b5144a26686afef6011eba8de59`.

### ImageMagick — accepted

- Version `7.1.2-30` portable Q16 x64.
- Asset `ImageMagick-7.1.2-30-portable-Q16-x64.7z`.
- SHA-256 `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`.
- Package `tools/imagemagick/`.
- Mandatory validation: executable/provenance, PE AMD64, exact Q16/version, isolated package-first PATH, real PNG create/identify, Stirling dependency acceptance.
- Acceptance: Run `33092698357` (#67), job `98589465377`, commit `d1801e8569a23a762035a39dc7295de0f19e6115`; artifact `9655904308`, digest `sha256:f09b2d20d249c94a783ef129ec36bf9050d7ea7201f76122f0cf091606e27f83`.

### Ghostscript — accepted

- Version `10.07.1` Win64.
- Upstream `ArtifexSoftware/ghostpdl-downloads`, release `gs10071`, asset `gs10071w64.exe`.
- SHA-256 `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`.
- Package `tools/ghostscript/`.
- Extract official NSIS with 7-Zip without executing the installer.
- Retain `bin/gswin64c.exe`; add byte-identical package-local `bin/gs.exe` because Stirling probes literal `gs`.
- Mandatory validation: provenance/hash/PE AMD64/version, isolated `where gs`, real PostScript -> PDF -> PNG and Stirling backend acceptance.
- **Acceptance:** Run `33104114920` (#68), job `98629258424`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004`; artifact `9660338658`, digest `sha256:843dfdad3def8072ced147ea3c208c01019ec397f0a5f49b3c5bfcbc47cda9cd`.

## Active candidate: Tesseract OCR 5.5.3

Source-backed decisions:

- official upstream: `tesseract-ocr/tesseract` release `5.5.3` (published 2026-07-24);
- official Win64 asset: `tesseract-ocr-w64-setup-5.5.3.20260724.exe`;
- official asset SHA-256: `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`;
- package root: `tools/tesseract/`;
- extract NSIS via 7-Zip without executing the installer;
- do not inherit upstream installer's moving `tessdata_fast/main` downloads;
- pin `tessdata_fast` to commit `87416418657359cb625c412a48b6e1d6d41c29bd`;
- bundle initial `eng`, `spa`, `osd` models with exact Git blob IDs:
  - eng `bbef4675053b5b468cdb477053e28b1c698ba08e`;
  - spa `72e901f13ca52cfe34cf239a368b9ed3c0ddaf26`;
  - osd `527457ca8f8fe1fda7c2f88bce3c0e4be12be9d0`.

Stirling's own OCR guidance requires `eng` as the base model and `RuntimePathConfig` prioritizes `TESSDATA_PREFIX`, so the existing portable Tauri bootstrap already supports package-local `tools/tesseract/tessdata` without a new Rust change.

`.github/scripts/prepare-tesseract.ps1` must:

- verify the official installer SHA-256;
- archive-extract without installation;
- normalize the real Win64 runtime;
- download models at the exact pinned commit;
- verify each model by Git blob object SHA-1, not merely filename;
- write fixed `version.txt`, `PROVENANCE.txt`, `SHA256SUMS.txt`;
- reject installer leakage into the product tree.

`.github/scripts/validate-tesseract.ps1` must:

- require AMD64 `tesseract.exe` and exact 5.5.3;
- require isolated `where tesseract` to resolve package-local executable;
- require package-local `TESSDATA_PREFIX`;
- verify exact `eng`, `spa`, `osd` blob pins and SHA metadata;
- require `--list-langs` to contain `eng`, `spa`, `osd`;
- run real English OCR;
- run real Spanish OCR;
- run real OSD against a rotated generated image;
- during real PDF_Tunner startup require Stirling not to report `Missing dependency: tesseract` and require the backend log to confirm package-local tessdata path;
- rerun in the final cleaned tree before ZIP.

**Do not call Tesseract accepted until the complete primary workflow is green with every previously accepted gate still enabled.**

## Primary workflow contract

Permanent path:

`.github/workflows/pdf-tunner-windows-portable.yml`

During active development only:

- `workflow_dispatch` plus one `push` trigger restricted to `pdf-tunner/windows-portable-v1`;
- branch-scoped concurrency + `cancel-in-progress: true`;
- `.github/scripts/publish-push-run-statuses.ps1` as a connector-readable push-run ID bridge.

Final state before `main`:

- remove the development `push` trigger;
- remove the Commit Status bridge and its unnecessary permissions;
- retain the permanent/manual validation workflow only;
- remove other temporary diagnostic mechanisms that are no longer required.

Current baseline sequence:

1. checkout fork and expose push run ID during development;
2. verify pinned upstream ancestry;
3. setup Node 22, Rust stable, Java 25 and Task;
4. `task desktop:prepare` + `task desktop:test`;
5. build production Tauri executable without installer;
6. assemble portable bootstrap;
7. stage/validate Fixed WebView2;
8. stage/validate qpdf;
9. stage/validate ImageMagick;
10. stage/validate Ghostscript;
11. stage/validate candidate Tesseract + pinned models;
12. validate bundled Java 25;
13. launch assembled PDF_Tunner and detect real backend port;
14. require `/api/v1/info/status` HTTP 200;
15. require package-local dependency acceptance for qpdf/ImageMagick/Ghostscript/Tesseract and package-local Tesseract data path;
16. assert AppData/TEMP/WebView2/Tauri/registry/process containment;
17. close normally and reject package-local orphan processes;
18. run deliberate two-launch Win32 window-state persistence/restore proof;
19. on failure collect resilient host/profile/registry/process/package diagnostics without recursively copying a live Chromium profile;
20. clear generated `data/`, require final portable layout and rerun external tool validators;
21. create ZIP + SHA-256;
22. upload a short-lived CI artifact only while this remains a non-release build.

## Remaining v1 roadmap — do not collapse this list

### A. External toolchain

After Tesseract, still required/investigated before v1:

1. OCRmyPDF;
2. LibreOffice;
3. UNO / `unoconvert` (or a source-compatible portable alternative if required);
4. Poppler including `pdftohtml`, `pdfinfo`, `pdfimages`;
5. portable Python runtime;
6. NumPy;
7. OpenCV;
8. WeasyPrint;
9. Calibre / `ebook-convert`;
10. `unpaper`;
11. `pngquant`;
12. conversion fonts;
13. explicit VeraPDF end-to-end validation;
14. investigate/build/package `jbig2enc` if technically viable;
15. find a technically viable portable RAR/CBR implementation or document the concrete limitation;
16. add any further dependency exposed by exact pinned Stirling source during feature auditing.

### B. Functional validation

- Tesseract OCR + OSD/languages;
- OCRmyPDF E2E;
- LibreOffice -> PDF;
- PDF -> supported Office formats where Stirling exposes them;
- HTML/URL -> PDF;
- WeasyPrint;
- Poppler/PDF HTML conversion;
- Calibre/EPUB;
- Python + NumPy + OpenCV operations used by Stirling;
- qpdf/Ghostscript/ImageMagick regressions;
- `pngquant`/`unpaper` when exercised;
- RAR/CBR if integrated;
- jbig2enc if integrated;
- representative end-to-end API tests across Stirling functional families;
- explicit proof that runner-installed software is not satisfying package tests.

### C. Release readiness

1. non-Enterprise feature parity audit against pinned Stirling 2.14.3;
2. final branding audit: executable/product/window strings, UI, icons/logos, metadata, updater behavior, ZIP/Release names;
3. final portability audit for every component's config/cache/temp/registry/process state;
4. CI/repository cleanup, including development push/status bridge;
5. final downstream diff hygiene review;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish clean v1 ZIP only when all gates are complete;
9. manual clean-machine Windows 10/11 checklist and user validation.

## Acceptance policy

A dependency/layer moves from candidate to accepted only when the **complete current primary workflow** is green, so previously accepted functionality is regression-tested at every new layer. Record:

- commit SHA;
- Run ID/number;
- job ID;
- relevant exact dependency version/source/hash;
- artifact ID/digest if the run produces the accepted short-lived artifact.

A green standalone preparation step is not acceptance.

## Upstream synchronization

For each future Stirling update:

1. inspect new upstream version/commit;
2. compare PDF_Tunner delta;
3. use a dedicated branch;
4. resolve only real conflicts;
5. re-audit relevant desktop/external-tool behavior;
6. rerun the complete portable suite;
7. update README + AGENTS in the same final change.

Do not recreate the application from scratch.

## Versioning/releases

- Keep upstream Stirling version visible.
- Do not invent unnecessary versions.
- Add PDF_Tunner revision suffixes only for real downstream revisions.
- No final Release exists yet.
- Before publication verify final ZIP SHA-256 and provenance.
- Only final published packages enter Release history.

## Current handoff — 2026-08-27

Accepted/closed:

- native portable/Tauri/AppData/window-state/bootstrap containment;
- Fixed WebView2 151.0.4129.101 x64;
- qpdf 12.4.0 MinGW64;
- ImageMagick 7.1.2-30 Q16 x64;
- Ghostscript 10.07.1 Win64 via primary Run `33104114920` (#68), job `98629258424`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004`, artifact `9660338658`, digest `sha256:843dfdad3def8072ced147ea3c208c01019ec397f0a5f49b3c5bfcbc47cda9cd`.

Active candidate:

- Tesseract 5.5.3 Win64 + pinned `eng`/`spa`/`osd` models.

Next block after Tesseract acceptance:

- OCRmyPDF, with Windows/Python packaging researched from current upstream sources before implementation.

Broader roadmap after that:

- the complete A/B/C lists above remain mandatory through final v1 Release and manual Windows validation.

## PDF_Tunner changelog — compact accepted milestones

- **2026-08-21:** real fork/base confirmed; Tauri + JLink architecture selected; portable bootstrap branch/workflow established.
- **2026-08-22:** real packaged startup/backend health, Java temp, protocol and parent/child shutdown brought under CI; WebView2/profile and custom portable window-state work added.
- **2026-08-23:** native Tauri stores/log/http cookies and two-launch window-state behavior audited/localized; consolidated AppData/window-state acceptance later proved by Run `32825188381`.
- **2026-08-27:** Fixed WebView2 accepted by Run #62; qpdf accepted by Run #66; ImageMagick accepted by Run #67; Ghostscript accepted by Run #68.
- **2026-08-27:** continuity protocol made explicit after a resumed conversation incorrectly narrowed the remaining roadmap; Tesseract 5.5.3 becomes the active candidate with official Win64 binary and exact pinned `tessdata_fast` models.

Detailed diagnostic chronology remains preserved in git history; this file intentionally prioritizes the current technical contract, accepted evidence, active candidate and full remaining roadmap so work can resume safely in a new conversation.
