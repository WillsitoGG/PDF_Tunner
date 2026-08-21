# AGENTS.md

This file is the permanent technical context and operating contract for **PDF_Tunner**. It overrides generic repository-cleanup conventions when those conventions would make this fork harder to compare or synchronize with Stirling upstream.

## 1. Project identity and objective

PDF_Tunner is not a wrapper repository. It is the real GitHub fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`.

Target distribution:

- Windows 10/11 x64;
- portable ZIP: extract and run;
- application name: `PDF_Tunner`;
- preserve Stirling functionality except functionality specifically belonging to Enterprise/SaaS offerings;
- bundle required runtimes and external conversion/OCR tools whenever technically viable;
- keep configuration, caches, logs, temporary files and runtime state within the portable directory as far as the underlying Windows APIs allow;
- remain straightforward to compare and update from upstream.

## 2. Pinned starting point

Initial upstream base:

- repository: `Stirling-Tools/Stirling-PDF`;
- version: `2.14.3`;
- commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`;
- Java toolchain/runtime: JDK/JRE 25;
- initial PDF_Tunner implementation branch: `pdf-tunner/windows-portable-v1`.

Always record a new upstream version and commit here before incorporating a future upstream update.

## 3. Non-negotiable repository rules

1. Preserve Stirling's upstream root structure. Do **not** reorganize the fork into generic root-level `Archive/`, `Source/` or `Validation/` trees.
2. `main` must remain clean and understandable. No committed build outputs, logs, temporary experiments, one-shot triggers or abandoned scripts.
3. Prefer small, localized downstream deltas over broad rewrites.
4. Never remove upstream functionality unless the user explicitly requests it or the functionality is specifically excluded from the PDF_Tunner target.
5. Do not claim a feature works because it compiles. Validate the final packaged executable and the relevant endpoint/conversion.
6. Failed/intermediate builds are never release history.
7. Keep historical git tags. Only final, actually published packages qualify for release history.
8. SHA-256/provenance belongs in the repository/validation record, not as miscellaneous Release assets unless a packaging decision explicitly requires otherwise.
9. **Every PDF_Tunner-specific change must update both `README.md` and `AGENTS.md` in the same commit.** This includes workflows, scripts, source code, packaging, dependency versions, validation behavior and release decisions.
10. Do not repeatedly turn licensing into the center of technical work. Mention a license only when it creates a concrete technical/distribution constraint.

## 4. Architecture decision

Use Stirling's own Tauri desktop implementation under `frontend/editor/src-tauri` as the PDF_Tunner desktop shell.

Do not restore the old architecture in `WillsitoGG/PDF_Tunner_Legacy`, where a separate .NET WinForms/WebView2 executable launched a Stirling JAR. The legacy repository is reference material only.

Useful ideas retained from the legacy project:

- profile/data redirection into the portable directory;
- bundled Java runtime;
- loopback-only local backend;
- backend readiness validation;
- process-tree cleanup;
- ZIP + SHA-256 validation;
- explicit dependency/version tests;
- keeping the Windows package self-contained.

The current Stirling desktop already supplies superior native implementations for backend lifecycle, Tauri WebView, single-instance behavior, file opening, drag/drop, dynamic backend port discovery and shutdown. Keep those upstream mechanisms unless there is a demonstrated portable-specific defect.

## 5. Desktop/JRE implementation facts

Upstream `.taskfiles/desktop.yml` is the source of truth for the desktop build.

At the initial base it:

- builds the backend boot JAR for desktop;
- bundles only host-appropriate JPDFium natives;
- constructs a Java 25 runtime via JLink;
- explicitly includes `jdk.dynalink` because VeraPDF requires it;
- includes `jdk.crypto.mscapi` on Windows;
- copies the JAR to `frontend/editor/src-tauri/libs`;
- copies the JLink runtime to `frontend/editor/src-tauri/runtime/jre`;
- runs Tauri/Cargo tests through `task desktop:test`.

The official desktop task currently builds with `DISABLE_ADDITIONAL_FEATURES=true`. Treat the distinction between core/proprietary/SaaS as a feature-partition question and verify it from source before changing flavor. Do not assume that changing flavor is necessary merely to obtain OCR/conversion tools: those tool families live in the core backend and are independently disabled when dependencies are absent.

## 6. Portable mode design

PDF_Tunner portable mode is activated by a marker file named:

`PDF_TUNNER_PORTABLE`

placed next to `PDF_Tunner.exe`.

Before Tauri initializes, PDF_Tunner redirects Windows process environment locations into the package-local `data/` tree. This matters because Tauri plugins, Java, Python, LibreOffice, Calibre and other child processes can otherwise inherit host profile/temp locations.

Portable environment targets include:

- `APPDATA`;
- `LOCALAPPDATA`;
- `PROGRAMDATA`;
- `USERPROFILE`;
- `HOME`;
- `TEMP`;
- `TMP`;
- PDF_Tunner's own portable-root marker/environment value.

Bundled tool directories are prepended to `PATH` only when present. Tool-specific environment variables such as `TESSDATA_PREFIX` are set only when their packaged resources exist.

Intended package layout:

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  libs/
  runtime/jre/
  tools/
  data/
```

Do not commit `data/` runtime contents.

## 7. External dependency source of truth

Do not build dependency lists from memory. At Stirling 2.14.3 the primary source-of-truth files are:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- relevant controller/service code for each tool.

`ExternalAppDepConfig` probes the following and disables feature groups when required dependencies are missing:

| Capability | Runtime command/check |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` (minimum 58) |
| Poppler HTML conversion | `pdftohtml` |
| UNO conversion | `unoconvert` |
| QPDF | `qpdf` (minimum 12) |
| Tesseract | `tesseract` |
| real CBR/RAR output | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |

The fat Docker base additionally installs/uses or stages:

- Calibre;
- Ghostscript;
- QPDF;
- ImageMagick;
- Poppler;
- `unpaper`;
- `pngquant`;
- LibreOffice;
- Tesseract language data + OSD;
- Python;
- WeasyPrint;
- `pdf2image`;
- OpenCV headless;
- OCRmyPDF;
- `unoserver`/Unoconvert infrastructure;
- fonts required by document conversion.

When adding a Windows binary/runtime, record its exact version, source and package layout here and in `README.md`.

## 8. Windows toolchain strategy

The final portable distribution should prefer deterministic, unpackable Windows builds over installers and machine-wide configuration.

Expected tool root is `tools/`. Keep each upstream tool in a clearly named subdirectory rather than dumping unrelated DLLs into the PDF_Tunner root. Add only required executable directories to `PATH`.

For tools whose Windows command differs from Stirling's expected command (for example Ghostscript commonly exposes `gswin64c.exe` while Stirling probes `gs`), provide a deterministic local shim/alias in the portable package and test the exact command that Stirling probes.

Do not rely on software preinstalled on the GitHub Actions Windows runner. Validation must explicitly resolve commands from the assembled PDF_Tunner package.

## 9. Build workflow

Permanent Windows portable workflow:

`.github/workflows/pdf-tunner-windows-portable.yml`

During stabilization it is manual (`workflow_dispatch`). It must build from this fork, not checkout a second upstream source tree as the legacy project did.

Baseline build sequence:

1. checkout the fork branch;
2. verify the documented upstream base is an ancestor;
3. install Node 22, Rust stable, Java 25 and Task;
4. run Stirling's official `task desktop:prepare` for `windows-x64`;
5. run `task desktop:test`;
6. build Tauri using the PDF_Tunner config overlay;
7. assemble an unpacked portable directory with the executable, JRE, backend JAR, marker and bundled tools;
8. validate the assembled directory;
9. generate one portable ZIP and its SHA-256 for CI validation;
10. publish a GitHub Release only after the package reaches release-ready status.

Temporary diagnostic steps may exist on the implementation branch but must be removed or converted into permanent validation before merge/release.

## 10. Validation standard

The final validation suite must cover, where automation is technically possible:

- executable startup;
- backend startup and dynamic port detection;
- `/api/v1/info/status`;
- bundled JRE version;
- dependency command resolution and versions;
- Tesseract OCR + OSD/languages;
- OCRmyPDF end-to-end;
- LibreOffice -> PDF;
- PDF -> supported Office formats where Stirling exposes it;
- WeasyPrint;
- HTML/URL -> PDF;
- Calibre/EPUB conversions;
- qpdf;
- Ghostscript;
- Poppler/pdftohtml;
- Python + OpenCV + NumPy where required by installed Python packages;
- ImageMagick;
- `pngquant` and `unpaper` when exercised by Stirling functionality;
- RAR/CBR when a technically redistributable/viable Windows implementation is available;
- jbig2enc if integrated;
- representative end-to-end API calls for every major Stirling functional family;
- portable path containment;
- clean Java/child-process shutdown;
- absence of accidental dependency on runner-installed tools;
- final ZIP integrity;
- SHA-256.

Distinguish automated CI validation from tests that the user must perform manually on a real Windows 10/11 PC.

## 11. Branding

Branding target is `PDF_Tunner` for:

- Tauri product/window/binary name;
- interface name where configurable without breaking upstream architecture;
- icons/logos where appropriate;
- portable ZIP and Releases.

Prefer an additive Tauri config overlay such as `frontend/editor/src-tauri/tauri.pdf-tunner.conf.json` over rewriting the upstream Tauri config wholesale.

Never leave the updater pointed at Stirling upstream in a way that could replace PDF_Tunner with an official Stirling binary. Until PDF_Tunner has its own signed updater metadata, treat in-app self-update as unavailable rather than silently consuming upstream releases.

## 12. Upstream synchronization

For a future Stirling update:

1. fetch/inspect the new upstream version and exact commit;
2. compare the PDF_Tunner delta with the new upstream;
3. update the fork through a dedicated branch;
4. resolve only real downstream conflicts;
5. re-audit dependency/path behavior if upstream touched external-tool, desktop/Tauri, packaging or configuration code;
6. rerun the complete Windows portable validation suite;
7. update both README and this file with the new base and relevant decisions.

Do not reconstruct the fork from scratch for each update.

## 13. Release/versioning rules

- Keep the upstream Stirling version visible.
- Do not invent unnecessary application versions.
- Add a PDF_Tunner tuning revision only when a real downstream revision exists.
- Before a final Release, verify exact ZIP SHA-256 and provenance.
- Only final published packages enter historical release tracking.
- When a final revision replaces an older final revision: validate/publish the new one first, record and verify the previous package/hash, remove the previous Release listing, retain its git tag, and clean temporary build infrastructure.

No final Release exists yet for this new real-fork implementation.

## 14. Upstream development conventions retained

This fork still follows Stirling's development conventions unless a PDF_Tunner rule above explicitly overrides them:

- use Task from repository root (`task --list`);
- run the relevant quality gate for the area changed;
- Java: JDK 25 / Spring Boot 4.x / Jackson 3 — inspect current repository imports before coding;
- frontend: Vite + React + TypeScript; normal imports use `@app/*` so build-layer shadowing continues to work;
- all frontend file state goes through `FileContext`;
- preserve Tauri backend cleanup and single-instance behavior;
- use `frontend/editor/DeveloperGuide.md`, root `DeveloperGuide.md`, `ADDING_TOOLS.md` and current source as authoritative implementation guidance.

The upstream AGENTS file at the pinned base can be consulted through `Stirling-Tools/Stirling-PDF` if more detailed upstream-only guidance is needed.

## 15. PDF_Tunner changelog

### Bootstrap v1 work — 2026-08-21

- Confirmed `WillsitoGG/PDF_Tunner` is a real GitHub fork of `Stirling-Tools/Stirling-PDF`.
- Confirmed fork `main` initially matched upstream exactly at `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632` / Stirling 2.14.3.
- Located legacy reference repository `WillsitoGG/PDF_Tunner_Legacy`.
- Chose Stirling's official Tauri desktop architecture instead of restoring the legacy C# wrapper.
- Audited official JLink/JRE 25 desktop behavior and the first external dependency inventory.
- Started branch `pdf-tunner/windows-portable-v1`.
- Added the PDF_Tunner portable-environment bootstrap, Tauri branding/config overlay and manual Windows portable build/validation workflow in the same documented change.
