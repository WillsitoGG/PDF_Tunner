# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this before repository changes.

## Identity and target

PDF_Tunner is `WillsitoGG/PDF_Tunner`, a real fork of `Stirling-Tools/Stirling-PDF`, not a wrapper.

- Pinned upstream: Stirling PDF `2.14.3`, commit `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`.
- Primary branch: `pdf-tunner/windows-portable-v1`.
- Current focused branch: `pdf-tunner/libreoffice-uno-candidate`.
- Target: Windows 10/11 x64 portable ZIP, extract/run, no installer/admin/global runtime dependency.
- Preserve non-Enterprise Stirling functionality unless an explicit portable limitation is technically unavoidable and documented.
- Keep `main` clean/upstream-comparable until final integration.
- Do not reopen old PR #1.
- No final v1 Release until toolchain, E2E, parity, branding, portability, cleanup and docs are complete.

For this project, **portable means sandbox-like containment**: app state, bundled runtimes/tools, config, cache, logs and temp stay under the portable tree whenever technically possible. Host tools must never silently satisfy validation.

## Mandatory repository rules

1. Preserve Stirling's repository structure and use its native Tauri desktop under `frontend/editor/src-tauri`.
2. Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable.
3. Do not globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before native Tauri/WebView2 initialization; localize per component.
4. Pin dependency version/source/SHA-256 and retain provenance.
5. Compilation or `--version` is insufficient when a real operation can be tested.
6. Heavy dev workflows use branch-specific concurrency with `cancel-in-progress:true`.
7. **Every PDF_Tunner-specific change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
8. Development-only workflows/scripts must be removed during final cleanup.
9. No failed/intermediate build becomes a Release.

## No-polling workflow rule

When work launches or depends on GitHub Actions:

- inspect state at most once per user turn;
- if `queued` or `in_progress`, stop dependent work and return control;
- never poll every seconds/minutes;
- inspect again only when the user explicitly resumes;
- do not push another commit to the same triggering branch while a relevant `cancel-in-progress:true` workflow is running unless that push is necessary to correct it.

## Portable boundary already accepted

Primary workflow has accepted together:

- native Tauri + bundled Java/JLink, package-local backend state and Java temp;
- Fixed WebView2 `151.0.4129.101` x64, Run #62;
- qpdf `12.4.0`, Run #66;
- ImageMagick `7.1.2-30` Q16 x64, Run #67;
- Ghostscript `10.07.1`, Run #68;
- Tesseract release `5.5.3` / CLI `5.5.3.20260724`, Run #70;
- Python `3.12.14` + OCRmyPDF `17.10.0`, primary Run `33201568275` (#77), job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31`;
- post-OCR full regression Run `33251329173` (#78), job `99097401718`, commit `694c1a01ac495bb906a3257b9c499b90ebb8b5db`, artifact `9714686816`, digest `sha256:740054517fa9733ae9f40e8a8fe319535f6fda0f5d1b5839744f984b8d354fbc`.

Existing component-local locations include `data/`, `data/tmp/`, `data/webview2/`, `data/tauri/...`, `tools/python/`, `tools/tesseract/`, `tools/ghostscript/`, `tools/qpdf/` and `tools/imagemagick/`. `tools/bin` is first in portable PATH and is appropriate for native compatibility shims.

## Stirling Office-conversion source contract

For pinned 2.14.3, inspect and preserve behavior from:

- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `app/common/src/main/java/stirling/software/common/util/ProcessExecutor.java`;
- `app/common/src/main/java/stirling/software/common/util/PDFToFile.java`;
- `app/core/src/main/java/stirling/software/SPDF/controller/api/converters/ConvertOfficeController.java`;
- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`.

Relevant behavior:

- non-Docker defaults are literal `soffice` and `unoconvert`;
- `ConvertOfficeController` tries `unoconvert --convert-to pdf INPUT OUTPUT`, then falls back to direct `soffice`;
- `PDFToFile` tries `unoconvert --convert-to FORMAT [--input-filter=FILTER] INPUT OUTPUT`, then falls back to direct `soffice`;
- `ProcessExecutor` recognizes an executable basename containing `unoconvert`/`unoconv`, acquires a concurrency endpoint lease and injects `--host`, `--port`, optional `--host-location`, optional `--protocol`;
- endpoint auto numbering begins at XML-RPC 2003 and increments by two, but the controller itself does not call an UNO server API;
- `ExternalAppDepConfig` independently probes LibreOffice and Unoconvert; on Windows availability is `where COMMAND` then `COMMAND --version` fallback.

Therefore full Windows parity requires both command probes to resolve intentionally, but it does **not** require reproducing the Linux/Docker unoserver architecture if a compatible Windows command preserves the same conversion behavior.

## Active candidate — LibreOffice 26.2.5 + native Windows `unoconvert` shim

Pinned LibreOffice:

- official Windows x86-64 MSI `26.2.5`;
- SHA-256 `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`.

Upstream unoserver 3.7 is historical research only, **not a Windows-v1 runtime requirement**. Its project states Windows support is untested. PDF_Tunner instead provides a native CLI compatibility shim backed by bundled LibreOffice.

Focused files:

- `.github/workflows/pdf-tunner-libreoffice-uno-candidate.yml`;
- `.github/scripts/prepare-libreoffice-uno-candidate.ps1`;
- `.github/scripts/unoconvert-launcher.rs`;
- `.github/scripts/validate-libreoffice-windows-shim.ps1`.

### Required shim contract

Compile `.github/scripts/unoconvert-launcher.rs` to `tools/bin/unoconvert.exe`.

It must:

- resolve the portable root relative to its own executable;
- use `tools/libreoffice/program/soffice.com` (fallback `.exe` only if needed);
- support `--version`;
- support `--convert-to VALUE` and `--convert-to=VALUE`;
- support `--input-filter VALUE` and `--input-filter=VALUE`;
- accept/ignore `--host`, `--port`, `--host-location`, `--protocol` in split or `=` form because Stirling injects them;
- require exactly INPUT and OUTPUT positionals;
- create a unique short package-local profile under `<root>/p/`;
- use `<root>/data/tmp/libreoffice` for child TEMP/TMP;
- translate `--input-filter` to LibreOffice `--infilter`;
- invoke `soffice --headless --nologo --convert-to ... --outdir OUTPUT_PARENT INPUT`;
- rename/move LibreOffice's basename-derived output to the exact requested OUTPUT;
- remove its transient profile and propagate failures.

### Focused Run #13 contract

**Before any MSI download**, parse active PowerShell scripts with `System.Management.Automation.Language.Parser` and compile the Rust source to a temporary executable. A syntax/compile failure must terminate cheaply.

Then:

1. MSI administrative-extract official LibreOffice; never install it.
2. Build package-local `tools/bin/unoconvert.exe`.
3. Copy the candidate to a realistic path with spaces such as `<RUNNER_TEMP>\PT Space\PDF Tunner`.
4. Execute a real direct `soffice` DOCX -> PDF fallback with profile/temp under the portable tree, matching Stirling's Java fallback behavior.
5. Execute `unoconvert --version`.
6. Execute exact Stirling-style Office -> PDF with injected host/port/location/protocol arguments.
7. Execute PDF -> DOCX with `--input-filter=writer_pdf_import`.
8. Prove `where soffice` and `where unoconvert` resolve package paths.
9. Prove no package-rooted LibreOffice processes remain.
10. Move the **already-used** tree to a second realistic path with spaces and repeat functional/probe tests.
11. Emit compact evidence.

This candidate intentionally does **not** claim arbitrary extreme path depth. LibreOffice has upstream long-path sensitivity. Spaces and relocation are mandatory; extreme path depth remains a final audit/known-limitation item.

Focused green is candidate evidence only. Primary acceptance additionally requires:

- package LibreOffice + shim into `pdf-tunner/windows-portable-v1`;
- `ExternalAppDepConfig` reports both LibreOffice and Unoconvert available from package paths;
- actual Stirling backend Office -> PDF and PDF -> Office routes succeed;
- all previously accepted primary gates remain green;
- ZIP/provenance/hash/relocation/state/process checks pass.

## LibreOffice focused history — authoritative summary

- #1 `33252792182`: harness `$LASTEXITCODE` failure after successful MSI extraction.
- #2 `33253632305`: original conversion passed; old relocated `.exe` invocation failed.
- #3 `33254174353`: `.com` alone did not fix the old relocation sequence.
- #4 `33254797382`: residual-process theory disproved.
- #5 `33256042222`: sequential warm-up matrix passed package-local variants only after an external first conversion; PyUNO import was proven but not required by the new Windows design.
- #6 `33256677474`: supposed cold source was not cold due preparation version probe.
- #7 `33257922780`: cold same-volume move failed in the old very-deep path setup.
- #8 `33258650349`: copy + source deletion failed there too.
- #9 `33259809371`: source dependency/reparse hypothesis disproved.
- #10 `33260616218`, artifact `9717213692`, digest `sha256:530fc588a2c9713de5400a9e1518e2d0242dd0d8b54d40656c7b5ffd447be1ba`: independent copies isolated deep profile-path sensitivity; external-all/package-I/O/package-TEMP passed, package-profile failed.
- #11 `33261426679`, artifact `9717449210`, digest `sha256:9536f144132954fd800f92a3b880dc518e536acdc59cb3effb01a7b1f237b9ca`: profile variants failed on very long roots; its long external control was not a clean single-variable control.
- #12 `33271242561`, job `99149973475`, artifact `9720176235`, digest `sha256:deb85bef8bb7775161d3a87081963905c6f56f55c5c09d4daba2f2f6d74b96ef`: **harness-only** parse failure (`$Drive:`). SUBST/LibreOffice/UNO functionality was never executed; draw no product conclusion.

## Primary acceptance contract

A dependency becomes accepted only when the complete primary workflow is green with every prior gate still enabled. Record exact version/source/hash plus commit/run/job/artifact/digest where relevant. A standalone focused workflow is diagnostic/candidate evidence only.

## Remaining roadmap

1. Focused LibreOffice + Windows `unoconvert` shim proof.
2. Primary integration and real Stirling Office conversion E2E.
3. Poppler (`pdftohtml`, `pdfinfo`, `pdfimages`).
4. Portable Python dependency consolidation, NumPy, OpenCV.
5. WeasyPrint.
6. Calibre/`ebook-convert`.
7. `unpaper`, `pngquant`, conversion fonts.
8. VeraPDF E2E; investigate `jbig2enc`; viable RAR/CBR or concrete documented limitation.
9. Representative Stirling API-family E2E and proof host tools do not satisfy tests.
10. Non-Enterprise parity audit vs pinned 2.14.3.
11. Final branding and sandbox/path/process/state audit on multiple folders, spaces, restricted locations, Windows 10/11 x64.
12. Remove development-only workflows/triggers/status bridges and retired candidate scripts.
13. Final downstream-diff hygiene and provenance/docs/version/hash.
14. Integrate to `main` without PR #1.
15. Publish clean v1 ZIP only after all gates, then manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-08-29

Accepted: native portable/Tauri containment, Fixed WebView2, qpdf, ImageMagick, Ghostscript, Tesseract, Python, OCRmyPDF; post-OCR primary Run #78 is green.

Current action: focused Windows LibreOffice 26.2.5 + native `unoconvert.exe` compatibility shim. Do not move to Poppler until this is accepted in the complete primary workflow.
