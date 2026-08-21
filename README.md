# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a GitHub fork of Stirling PDF: the project tunes that fork directly rather than rebuilding Stirling behind a separate wrapper.

## Base and status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Initial upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- Status: **portable bootstrap under active validation; no final Release yet**

The full original Stirling documentation and developer guide remain in this fork. Upstream project information is available at [Stirling-Tools/Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF).

## Architecture

PDF_Tunner uses Stirling's own Tauri desktop application in `frontend/editor/src-tauri`. The old private `WillsitoGG/PDF_Tunner_Legacy` C#/WebView2 launcher is reference material only.

The current approach preserves the upstream desktop lifecycle and reuses:

- Tauri desktop shell and WebView;
- single-instance/file-opening logic;
- bundled Java backend lifecycle and shutdown;
- JDK 25 runtime produced with JLink;
- dynamic loopback backend port;
- Stirling's own React frontend and complete source tree.

Our downstream work is concentrated on **portable paths, bundled external tools, branding, packaging and validation**.

## Portable mode

Portable mode is explicit: it activates when a file named `PDF_TUNNER_PORTABLE` exists next to `PDF_Tunner.exe`.

Before Tauri starts, the Windows process redirects `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP`, `TMP` and cache locations into the package-local `data/` tree. Bundled tool directories are prepended to `PATH` only when present, and packaged Tesseract data is exposed through `TESSDATA_PREFIX` when available.

Intended final layout:

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  libs/
  runtime/jre/
  tools/
  data/
```

`data/` contains runtime state and must not be committed.

## External dependency inventory

This list comes from Stirling 2.14.3 source (`ExternalAppDepConfig`, `RuntimePathConfig` and the fat Docker toolchain), not from assumptions about older releases.

Stirling directly probes and can disable feature groups for missing:

| Capability | Command/check |
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

The upstream fat toolchain also confirms use of `unpaper`, `pngquant`, LibreOffice/UNO infrastructure, Tesseract OSD/languages, `pdf2image`, OpenCV, OCRmyPDF and conversion fonts. These are being integrated into `tools/` incrementally and will not be marked supported until the assembled Windows package passes real tests.

## Build and validation

Workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

During active development it has both `workflow_dispatch` and a **temporary `push` trigger restricted to `pdf-tunner/windows-portable-v1`** so the autonomous build/fix loop can run without manual UI interaction. The branch-scoped push trigger must be removed before the final change reaches `main`.

Bootstrap validation currently targets:

- documented upstream-base ancestry;
- official Tauri/Cargo tests;
- production Tauri executable;
- bundled Java 25 runtime;
- package-local portable marker/data paths;
- real Java backend startup and dynamic port detection;
- `/api/v1/info/status` health response;
- clean parent/child-process shutdown;
- clean ZIP generation;
- SHA-256 generation.

The next validation layers will exercise every external dependency and representative end-to-end Stirling operation before any final Release is published.

## Upstream synchronization

To keep future Stirling updates manageable:

- preserve the original Stirling root structure;
- do not reorganize the fork into generic root `Archive/`, `Source/` or `Validation/` trees;
- localize PDF_Tunner-specific code/config/workflows;
- keep the exact upstream version and commit documented;
- compare the downstream delta before each upstream update;
- rerun the complete Windows portable suite after rebasing/updating.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same commit.** They are the permanent record of architecture, dependencies, build, packaging, portability, validation, releases and tuning history.

For upstream build/development details, use the existing `DeveloperGuide.md`, `frontend/editor/DeveloperGuide.md`, `ADDING_TOOLS.md` and the source itself.
