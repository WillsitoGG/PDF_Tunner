# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable/sandboxed tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner modifies Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and target

- Upstream: `Stirling-Tools/Stirling-PDF`
- Pinned upstream version: **2.14.3**
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Main portable-development branch: `pdf-tunner/windows-portable-v1`
- Current focused candidate branch: `pdf-tunner/libreoffice-uno-candidate`
- Target: **Windows 10/11 x64 portable ZIP**, extract and run.
- No final PDF_Tunner v1 Release exists yet. `main` remains the clean upstream base during v1 development.

For this project, **portable means sandbox-like containment**: application, runtimes, external tools, configuration, caches, logs, temporary files and runtime state must remain inside the PDF_Tunner tree whenever the underlying Windows component allows it. The host must not be used as an undeclared dependency.

## Accepted portable layers

The complete primary Windows workflow has accepted all of the following together:

- Stirling's native Tauri desktop + bundled Java/JLink runtime;
- package-local backend state, Java temp, Tauri logs/store/cookies/window state and clean shutdown;
- Fixed WebView2 `151.0.4129.101` x64;
- qpdf `12.4.0` MinGW64;
- ImageMagick `7.1.2-30` portable Q16 x64;
- Ghostscript `10.07.1` Win64;
- Tesseract release `5.5.3`, Windows CLI `5.5.3.20260724`, with pinned `eng`, `spa` and `osd` models;
- Python `3.12.14` x64 from `astral-sh/python-build-standalone`;
- OCRmyPDF `17.10.0` with a native relocatable `tools/python/ocrmypdf.exe` launcher.

### Key acceptance evidence

| Layer | Primary acceptance evidence |
| --- | --- |
| Fixed WebView2 | Run `33058462619` (#62) |
| qpdf | Run `33086404875` (#66) |
| ImageMagick | Run `33092698357` (#67) |
| Ghostscript | Run `33104114920` (#68) |
| Tesseract | Run `33122172947` (#70) |
| Python + OCRmyPDF | Run `33201568275` (#77), job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31` |
| Post-OCR full regression | Run `33251329173` (#78), job `99097401718`, commit `694c1a01ac495bb906a3257b9c499b90ebb8b5db` |

Run #77 produced artifact `9698621272`, Actions digest `sha256:68f69bb0d4ed6b731aefee82abff3eba7b01d18c5b270051e2e546337cd6a164`.

Run #78 reconfirmed the complete accepted stack after OCRmyPDF candidate-gate retirement. Its artifact is `9714686816`, Actions digest `sha256:740054517fa9733ae9f40e8a8fe319535f6fda0f5d1b5839744f984b8d354fbc`.

## Portable boundary already implemented

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`.

Current component-local state strategy:

- Stirling backend config/logs/working state -> `data/`;
- Java temp -> `data/tmp/`;
- WebView2 profile -> `data/webview2/`;
- Tauri logs/store/cookies/window state -> `data/tauri/...`;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- Tesseract models -> `tools/tesseract/tessdata/` via `TESSDATA_PREFIX`;
- Python/OCRmyPDF -> `tools/python/`;
- OCRmyPDF temp -> `data/tmp/ocrmypdf/`;
- Python cache -> `data/python-cache/`;
- Calibre config -> `data/calibre/` when Calibre is added.

Portable mode does not globally replace Windows profile variables before native Tauri/WebView2 initialization. State is localized per component. Runtime `pdf-tunner://` protocol registration is also skipped in portable mode.

## Active candidate: LibreOffice 26.2.5 + UNO/unoconvert

The next source-backed Stirling dependencies are `soffice` and `unoconvert`.

Pinned candidate inputs:

- LibreOffice **26.2.5 Windows x86-64** official MSI from The Document Foundation;
- MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`;
- unoserver **3.7** from PyPI;
- `unoserver-3.7-py3-none-any.whl` SHA-256: `fc44e6808071c9d2957e705ecf1742cea8a582aa5d5cc23babf36bb332ec6e8e`.

Focused workflow: `.github/workflows/pdf-tunner-libreoffice-uno-candidate.yml`.

Candidate preparation performs an MSI **administrative extraction**, not a LibreOffice installation. The extracted suite is copied under `tools/libreoffice/`; the pure-Python unoserver wheel is extracted under `tools/unoserver/` with exact hash/provenance. Preparation deliberately does **not** launch `soffice`; the runtime version check and all functional execution happen only after the strict gate has relocated the package.

The focused gate is designed to answer the Windows-specific questions before primary integration:

1. Does official LibreOffice 26.2.5 run from an extracted, relocatable tree?
2. Does real DOCX -> PDF conversion succeed with profile and TEMP/TMP inside candidate `data/`?
3. Does the same operation work when the complete cold candidate is relocated to a path containing spaces before its first functional LibreOffice start?
4. Does the Windows LibreOffice package expose a compatible `program/python.exe`?
5. Can that interpreter `import uno` and the pinned unoserver package?
6. Can a real unoserver listener bind `127.0.0.1:2003` with UNO on `127.0.0.1:2004` and perform a real unoconvert DOCX -> PDF conversion?

A focused green result is **candidate evidence only**. LibreOffice/UNO will not become accepted until the same layer is integrated into the complete primary portable workflow and all previously accepted gates remain green.

## External dependency source of truth

Stirling 2.14.3 directly probes or executes:

| Capability | Runtime probe |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` >= 58 |
| Poppler HTML conversion | `pdftohtml` |
| UNO conversion | `unoconvert` |
| qpdf | `qpdf` >= 12 |
| Tesseract | `tesseract` |
| CBR/RAR | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |

The pinned source also uses or exposes Poppler helpers (`pdfinfo`, `pdfimages`), `unpaper`, `pngquant`, NumPy/OpenCV, conversion fonts, VeraPDF-related functionality and other utilities that remain subject to parity audit.

## Acceptance contract

A dependency is accepted only when the **complete current primary workflow** is green with all earlier accepted gates still enabled. `--version` is never sufficient where a real operation is practical. Tests must use package-local executable paths/environment so runner-installed software cannot satisfy the gate accidentally.

## Remaining v1 roadmap

1. Finish LibreOffice focused candidate and integrate `soffice` into primary.
2. Resolve and integrate real UNO/`unoconvert` support, preserving sandbox containment and child-process cleanup.
3. Poppler: `pdftohtml`, `pdfinfo`, `pdfimages`.
4. Portable Python dependency consolidation, NumPy and OpenCV.
5. WeasyPrint.
6. Calibre / `ebook-convert`.
7. `unpaper`, `pngquant` and conversion fonts.
8. Explicit VeraPDF E2E; investigate `jbig2enc`; establish viable RAR/CBR support or document the concrete technical limitation.
9. Representative E2E operations across Stirling feature families.
10. Non-Enterprise parity audit against pinned Stirling 2.14.3.
11. Final PDF_Tunner branding audit.
12. Final sandbox/portability audit on multiple folders, paths with spaces, restricted locations and Windows 10/11 x64.
13. Remove development-only workflows/triggers/status bridges and review the complete downstream diff.
14. Final provenance/docs/version/hash record.
15. Integrate to `main` without reopening old PR #1.
16. Publish the clean v1 ZIP only after all gates, then perform the manual clean-machine Windows 10/11 checklist.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**

## LibreOffice/UNO candidate diagnostics

Focused Run `33252792182` (#1), job `99101259425`, failed during candidate preparation after the official LibreOffice MSI had already downloaded, hash-validated and administrative-extracted successfully. The failure was a PowerShell harness defect: `Set-StrictMode` attempted to read an unset `$LASTEXITCODE` after launching `soffice.exe`, whose Windows GUI-subsystem launch semantics do not reliably populate that variable in this context. No LibreOffice/UNO functional conclusion is drawn from Run #1.

The next candidate revision replaces those `soffice.exe` `$LASTEXITCODE` checks with explicit `System.Diagnostics.Process` execution/capture, while retaining the same pinned LibreOffice/unoserver inputs, real conversion tests, relocation test and sandbox-local profile/TEMP/TMP requirements.

Focused Run `33253632305` (#2), job `99103473257`, advanced materially: preparation completed, pinned LibreOffice/unoserver payloads were validated, and a real package-local DOCX -> PDF conversion succeeded in the original extracted location with sandbox-local profile and TEMP/TMP. The only failure occurred after relocation to a path containing spaces: the candidate harness invoked `soffice.exe`, which returned success but produced no PDF. LibreOffice's own Windows command-line documentation specifies `soffice.com` for console/headless command-line operations and reserves `soffice.exe` for non-console use. The next candidate revision therefore keeps the relocation gate unchanged but executes direct headless conversions through package-local `soffice.com` (falling back to `.exe` only if `.com` is absent). This is a harness correction, not a relaxation of portability requirements.

Focused Run `33254174353` (#3), job `99104896585`, confirmed that switching to the official Windows console launcher was not sufficient: original-location DOCX -> PDF again passed, while the post-move conversion still returned success without producing a PDF. The next candidate therefore tests the remaining high-probability Windows cause explicitly: package-local `soffice.bin`/LibreOffice child processes that can outlive the CLI launcher. It records any residual process, closes only processes rooted under the candidate `tools/libreoffice/program` tree before relocation, verifies none remain, then repeats the unchanged path-with-spaces conversion gate.

Focused Run `33254797382` (#4), job `99106520093`, disproved the residual-process hypothesis: the package had zero LibreOffice processes remaining before relocation, yet the same already-used-tree relocation still failed. No hidden `soffice.bin` process was responsible.

Focused Run `33256042222` (#5), job `99109804816`, artifact `9715865060`, digest `sha256:f6711db687a6938b9c787fad7d1c95dd15a3b4ab1a28a217b45f2a459b611494`, isolated the actual boundary. A **cold copy** of the package relocated to a path containing spaces passed every matrix probe: relocated executable, package-local profile, package-local input/output, package-local TEMP/TMP, and the all-package combination all produced valid PDFs. The same evidence also proved that official LibreOffice 26.2.5 for Windows includes `program\python.exe`, and that this interpreter can `import uno` plus pinned `unoserver 3.7` both before and after cold relocation. The old strict sequence still failed only because it performed a real conversion first and then same-volume moved that already-initialized tree.

Run #6 therefore changes the focused acceptance sequence without weakening the portable target: **relocate the complete cold package before the first functional start**, then require two consecutive real package-local DOCX -> PDF conversions from the relocated sandbox, zero remaining package-local LibreOffice processes, PyUNO/unoserver import, and a real unoserver + unoconvert conversion on `127.0.0.1:2003` / UNO `2004`. Moving an already-used LibreOffice tree remains a separate portability edge case to resolve or explicitly mitigate before final v1 release; it is not being silently reclassified as supported.

Focused Run `33256677474` (#6), job `99111522324`, artifact `9716045830`, digest `sha256:dd23b222a4910c588e9fa30e9b76621fb9dfb2a8453579a0ce637bc59cbc00ca`, exposed a harness sequencing defect rather than a LibreOffice portability failure. The relocation matrix again passed all five cold-copy probes, but the strict validator's claimed "cold" source had already executed `soffice --version` during the preparation step. Therefore it was not cold before `Move-Item`. Run #7 removes every LibreOffice process launch from preparation, defers the runtime version check until after relocation, and removes the already-proven diagnostic matrix from the automatic pre-validation path so no earlier LibreOffice instance can contaminate the strict gate.


Focused Run `33257922780` (#7), job `99114759528`, artifact `9716396378`, digest `sha256:20f20265845616fbe8ba0527889bb7dafc8947694d07b7deea0e03249373fab5`, proved that removing all pre-relocation LibreOffice starts was not sufficient for a same-volume directory rename: the genuinely cold tree still returned success without a PDF on its first conversion after `Move-Item`. This does **not** contradict Run #5's five green cold-copy probes; it narrows the unresolved behavior specifically to NTFS rename/move semantics. To keep UNO feasibility moving forward without hiding that blocker, Run #8 materializes the untouched cold package at the space-containing destination by `Copy-Item`, deletes the source, and then runs the strict repeated-conversion + PyUNO + unoserver/unoconvert gate there. Same-volume in-place rename/move remains an explicit portability blocker for later root-cause analysis/mitigation and is not accepted by this candidate step.

Focused Run `33258650349` (#8), job `99116663366`, artifact `9716613454`, digest `sha256:bbb320446a3813104548e047f2e7a342ac1ff22d64517f956d63be2f34ad0913`, showed that **copy + delete source is not equivalent to the green cold-copy matrix**: after the untouched candidate was copied to the path-with-spaces destination and the original tree was deleted, the destination again returned success without producing the first PDF. The decisive difference from Run #5 is now whether the original extracted tree still exists. This introduces a stronger portability concern than the earlier rename-only hypothesis: the copied LibreOffice payload may retain an absolute-path or filesystem-link dependency on its source tree.

Run #9 therefore keeps the source tree temporarily, records reparse points and obvious absolute source-path references, then runs the complete destination stack through real direct conversion, PyUNO, unoserver and unoconvert. It preserves that evidence, deletes the source tree, and repeats from fresh conversion workspaces. A destination that works only while the source exists is **not** accepted as portable; the test is diagnostic and is intended to expose the exact source dependency while also allowing the UNO layer itself to be exercised.
