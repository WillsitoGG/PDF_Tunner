# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable/sandboxed tuning of the real [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner modifies Stirling directly rather than wrapping it in a separate application.

## Base and target

- Upstream: `Stirling-Tools/Stirling-PDF`
- Pinned upstream version: **2.14.3**
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Primary portable branch: `pdf-tunner/windows-portable-v1`
- Current focused branch: `pdf-tunner/libreoffice-uno-candidate`
- Target: **Windows 10/11 x64 portable ZIP**, extract and run; no installer, admin requirement or undeclared global runtime dependency.
- `main` remains the clean upstream base during v1 development.
- No final PDF_Tunner v1 Release exists yet.

For this project, **portable means sandbox-like containment**: application state, bundled runtimes/tools, config, caches, logs and temp remain inside the PDF_Tunner tree whenever the underlying Windows component allows it. The host must not silently satisfy package tests.

## Accepted portable stack

The complete primary Windows workflow already accepts these layers together:

| Layer | Version / evidence |
| --- | --- |
| Native Tauri + bundled Java/JLink | package-local backend state, Java temp, Tauri stores/logs/cookies/window state, protocol containment, clean shutdown |
| Fixed WebView2 | `151.0.4129.101` x64; Run `33058462619` (#62) |
| qpdf | `12.4.0`; Run `33086404875` (#66) |
| ImageMagick | `7.1.2-30` Q16 x64; Run `33092698357` (#67) |
| Ghostscript | `10.07.1`; Run `33104114920` (#68) |
| Tesseract | release `5.5.3`, CLI `5.5.3.20260724`; Run `33122172947` (#70) |
| Python + OCRmyPDF | Python `3.12.14`, OCRmyPDF `17.10.0`; Run `33201568275` (#77), job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31` |
| Post-OCR full regression | Run `33251329173` (#78), job `99097401718`, commit `694c1a01ac495bb906a3257b9c499b90ebb8b5db` |

Run #78 artifact: `9714686816`; Actions digest `sha256:740054517fa9733ae9f40e8a8fe319535f6fda0f5d1b5839744f984b8d354fbc`.

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`. Important component-local paths already include `data/`, `data/tmp/`, `data/webview2/`, `data/tauri/...`, `tools/python/`, `tools/tesseract/`, `tools/ghostscript/`, `tools/qpdf/` and `tools/imagemagick/`. PDF_Tunner does not globally replace Windows profile variables before native Tauri/WebView2 initialization.

## Current candidate: LibreOffice 26.2.5 + Windows `unoconvert` compatibility shim

The next Stirling dependencies are `soffice` and `unoconvert`.

Pinned LibreOffice input:

- LibreOffice **26.2.5 Windows x86-64** official MSI from The Document Foundation;
- SHA-256 `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`.

Preparation uses MSI **administrative extraction**, so LibreOffice is not installed on the runner. The suite is placed under `tools/libreoffice/`.

### Why the Windows design changed

Runs #1-#12 were useful diagnostically, but the candidate became overfitted to an artificial long CI path and to upstream `unoserver`. A source review of Stirling 2.14.3 shows that:

- `ConvertOfficeController` calls `unoconvert --convert-to pdf INPUT OUTPUT`, then falls back to `soffice`;
- `PDFToFile` calls `unoconvert --convert-to FORMAT [--input-filter=FILTER] INPUT OUTPUT`, then falls back to `soffice`;
- `ProcessExecutor` may inject `--host`, `--port`, `--host-location` and `--protocol` when the executable is named `unoconvert`/`unoconv`;
- `ExternalAppDepConfig` only needs `unoconvert` to resolve on Windows or return success for `--version`;
- upstream `unoserver` itself describes Windows support as untested.

Therefore Windows v1 no longer requires a persistent unoserver daemon. PDF_Tunner now builds a small **native relocatable `tools/bin/unoconvert.exe` compatibility shim**, analogous to the accepted OCRmyPDF launcher. It accepts Stirling's exact CLI, ignores endpoint metadata, creates a unique package-local LibreOffice profile, keeps native temp under `data/tmp/libreoffice`, invokes bundled `soffice.com`, and places the generated document at the exact output path Stirling requested.

### Focused Run #13 contract

Before any large download, the workflow must parse all active PowerShell scripts and compile the Rust shim source. Only then may it prepare LibreOffice.

The focused gate must prove all of the following in **two realistic Windows locations containing spaces**, with the second reached by moving the already-used tree:

1. direct Stirling-style `soffice` fallback converts real DOCX -> PDF with package-local Java-style temp/profile paths;
2. `unoconvert.exe --version` succeeds and identifies the bundled LibreOffice version;
3. the shim accepts injected endpoint arguments and converts real DOCX -> PDF;
4. the shim converts the resulting PDF -> DOCX with `--input-filter=writer_pdf_import`;
5. `where soffice` and `where unoconvert` resolve package binaries, not runner software;
6. the already-used portable tree can be moved to a second path with spaces and all functional tests still pass;
7. no package-rooted LibreOffice process remains after validation.

This gate intentionally does **not** claim support for arbitrarily deep Windows paths. LibreOffice itself has long-path sensitivity. Normal relocation and spaces are required; extreme path depth remains an explicit portability limitation/audit item rather than an artificial hard requirement.

A focused green result is **candidate evidence only**. Acceptance requires integration into `pdf-tunner/windows-portable-v1`, actual Stirling backend Office -> PDF and PDF -> Office routes, `ExternalAppDepConfig` seeing both dependencies, and a complete primary regression with all prior gates still green.

## LibreOffice diagnostic record

- #1 `33252792182`: PowerShell `$LASTEXITCODE` harness defect after successful MSI extraction.
- #2 `33253632305`: original conversion passed; relocated `.exe` CLI path failed.
- #3 `33254174353`: switching to `soffice.com` was insufficient for the old relocation sequence.
- #4 `33254797382`: residual-process hypothesis disproved.
- #5 `33256042222`: sequential cold-copy matrix passed after an external first conversion; PyUNO import was also proven, but the matrix was not an independent cold-first-use proof.
- #6 `33256677474`: strict source was not actually cold because preparation had executed `--version`.
- #7 `33257922780`: genuinely cold same-volume `Move-Item` still failed on the old deep-path setup.
- #8 `33258650349`: copy + source deletion also failed there.
- #9 `33259809371`: source-tree dependency disproved; zero reparse points.
- #10 `33260616218`, job `99121803242`, artifact `9717213692`, digest `sha256:530fc588a2c9713de5400a9e1518e2d0242dd0d8b54d40656c7b5ffd447be1ba`: independent copies isolated the deep-path profile boundary (`EXTERNAL_ALL`, package I/O and package TEMP passed; package profile failed).
- #11 `33261426679`, job `99123930051`, artifact `9717449210`, digest `sha256:9536f144132954fd800f92a3b880dc518e536acdc59cb3effb01a7b1f237b9ca`: all tested profile forms failed on very long roots; its long external control was not a clean one-variable test.
- #12 `33271242561`, job `99149973475`, artifact `9720176235`, digest `sha256:deb85bef8bb7775161d3a87081963905c6f56f55c5c09d4daba2f2f6d74b96ef`: **harness-only**. PowerShell rejected `$Drive:` before the SUBST/LibreOffice test ran. No product conclusion may be drawn from #12.

## Dependency source of truth

Stirling 2.14.3 directly probes or executes `gs`, `ocrmypdf`, `soffice`, `weasyprint`, `pdftohtml`, `unoconvert`, `qpdf`, `tesseract`, `rar`, `ebook-convert`, `magick`, Python and OpenCV. The pinned source also exposes Poppler helpers, `unpaper`, `pngquant`, conversion fonts, VeraPDF-related functionality and other utilities that remain subject to parity audit.

## Acceptance contract

A dependency becomes accepted only when the **complete current primary workflow** is green with every previously accepted gate still enabled. `--version` alone is never sufficient where a representative real operation is practical. Tests must use package-local executable paths/environment so runner-installed software cannot satisfy them accidentally.

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**

## Remaining v1 roadmap

1. Focused LibreOffice + native Windows `unoconvert` shim proof.
2. Integrate both into the primary package and validate actual Stirling Office conversion routes.
3. Poppler: `pdftohtml`, `pdfinfo`, `pdfimages`.
4. Portable Python dependency consolidation, NumPy and OpenCV.
5. WeasyPrint.
6. Calibre / `ebook-convert`.
7. `unpaper`, `pngquant` and conversion fonts.
8. Explicit VeraPDF E2E; investigate `jbig2enc`; viable RAR/CBR or concrete documented limitation.
9. Representative E2E operations across Stirling feature families.
10. Non-Enterprise parity audit against Stirling 2.14.3.
11. Final branding and sandbox/portability/state/process audit across multiple folders, spaces, restricted locations and Windows 10/11 x64.
12. Remove development-only workflows/triggers/status bridges and review the downstream diff.
13. Final provenance/docs/version/hash record.
14. Integrate to `main` without reopening PR #1.
15. Publish the clean v1 ZIP only after all gates, then perform the manual clean-machine Windows 10/11 checklist.
