# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a GitHub fork of Stirling PDF: the project tunes that fork directly rather than rebuilding Stirling behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- Current accepted portable/tool layers: Tauri/JRE/bootstrap containment, Fixed WebView2 `151.0.4129.101` x64, qpdf `12.4.0` MinGW64, ImageMagick `7.1.2-30` portable Q16 x64 and Ghostscript `10.07.1` Win64.
- Active candidate: **Tesseract OCR release 5.5.3 / Windows CLI build 5.5.3.20260724 with pinned `eng`, `spa` and `osd` tessdata models**.
- No final PDF_Tunner v1 Release exists yet. `main` remains the clean upstream base while the portable implementation is developed and validated on `pdf-tunner/windows-portable-v1`.

The original Stirling documentation and developer guides remain part of this fork. PDF_Tunner-specific architecture, packaging and validation decisions are recorded here and in `AGENTS.md`.

## Architecture

PDF_Tunner uses Stirling's own Tauri desktop application in `frontend/editor/src-tauri`. The old private `WillsitoGG/PDF_Tunner_Legacy` C#/WebView2 launcher is reference material only.

The downstream implementation preserves Stirling's desktop lifecycle and reuses:

- Tauri desktop shell and WebView;
- single-instance/file-opening logic;
- bundled Java backend lifecycle and shutdown;
- Java 25 runtime produced with JLink;
- dynamic loopback backend port;
- Stirling's React frontend and complete source tree.

PDF_Tunner-specific work is deliberately concentrated on **portable paths, bundled external tools, branding, packaging and validation**.

## Portable mode

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`.

The first CI experiments proved that globally replacing Windows profile variables before Tauri initialization can terminate the native application before setup/backend logging. PDF_Tunner therefore uses component-specific redirection instead of replacing `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` globally.

Current package-local state includes:

- Stirling backend config/logs/working state -> `data/`;
- Java temporary state -> `data/tmp/` through `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=...`;
- WebView2 profile -> `data/webview2/`;
- Tauri log files -> `data/logs/tauri/`;
- Tauri connection/token stores -> `data/tauri/store/`;
- portable window state -> `data/tauri/window-state/.window-state.json`;
- Tauri HTTP cookie jar -> `data/tauri/http/.cookies`;
- Calibre config -> `data/calibre/` when Calibre is present;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- packaged Tesseract data -> `tools/tesseract/tessdata/` through `TESSDATA_PREFIX`.

Portable mode also skips runtime `pdf-tunner://` protocol registration. Startup/shutdown validation rejects new host Stirling/PDF_Tunner state in the tracked AppData/TEMP/registry locations and checks for package-local child-process cleanup.

### Window-state portability

`tauri-plugin-window-state` cannot choose a portable path on Windows, so PDF_Tunner keeps the official plugin for non-portable behavior but substitutes a localized implementation in portable mode. The portable implementation preserves the upstream state shape and lifecycle semantics and stores state under `data/tauri/window-state/.window-state.json`.

Run `32825188381` is the accepted two-launch/AppData containment proof: the production executable persisted deliberately changed Win32 geometry inside the package and restored it on the second launch while the tracked host Roaming/Local state remained empty/contained.

## Intended portable layout

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  UPSTREAM_BASE.txt
  libs/
  runtime/
    jre/
    webview2/
      fixed/
      PROVENANCE.txt
      SHA256SUMS.txt
      version.txt
  tools/
    qpdf/
      bin/qpdf.exe
      PROVENANCE.txt
      SHA256SUMS.txt
      version.txt
    imagemagick/
      magick.exe
      PROVENANCE.txt
      SHA256SUMS.txt
      version.txt
    ghostscript/
      bin/
        gswin64c.exe
        gs.exe
      lib/
      PROVENANCE.txt
      SHA256SUMS.txt
      version.txt
    tesseract/
      tesseract.exe
      tessdata/
        eng.traineddata
        spa.traineddata
        osd.traineddata
      PROVENANCE.txt
      SHA256SUMS.txt
      version.txt
  data/
```

`data/` is runtime state and must never be committed or shipped pre-populated in the final clean ZIP.

## External dependency source of truth

The external-tool inventory is source-backed from Stirling 2.14.3, especially `ExternalAppDepConfig`, `RuntimePathConfig`, the fat Docker toolchain and the relevant feature controllers/services.

| Capability | Stirling runtime check |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` (minimum 58) |
| Poppler HTML conversion | `pdftohtml` |
| UNO conversion | `unoconvert` |
| qpdf | `qpdf` (minimum 12) |
| Tesseract | `tesseract` |
| CBR/RAR | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |

The pinned source also uses/probes Poppler helpers such as `pdfinfo`/`pdfimages` and the upstream toolchain confirms `unpaper`, `pngquant`, LibreOffice/UNO infrastructure, Tesseract OSD/languages, `pdf2image`, OpenCV, OCRmyPDF and conversion fonts. These remain part of the pre-v1 parity work and are not considered supported merely because the application starts.

## Accepted Windows toolchain layers

### Fixed WebView2 — accepted

- Version: `151.0.4129.101` x64.
- Pinned official CAB SHA-256: `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`.
- Package root: `runtime/webview2/fixed/`.
- No Evergreen/system fallback is accepted for the portable proof.
- Acceptance: primary Run `33058462619` (#62), job `98471041328`, commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4`.

### qpdf — accepted

- Version: `12.4.0`.
- Package: official `qpdf-12.4.0-mingw64.zip`.
- SHA-256: `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`.
- Package root: `tools/qpdf/`.
- Validation includes isolated package-first PATH plus a generated valid PDF checked with `qpdf --check` and exact page count, not the legacy mislabeled HTML fixture.
- Acceptance: primary Run `33086404875` (#66), job `98567113737`, commit `413994c9ea368b5144a26686afef6011eba8de59`.

### ImageMagick — accepted

- Version: `7.1.2-30` portable Q16 x64.
- Package: official `ImageMagick-7.1.2-30-portable-Q16-x64.7z`.
- SHA-256: `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`.
- Package root: `tools/imagemagick/`.
- Validation requires PE AMD64, exact version/Q16, isolated `where magick`, real PNG creation/identification and Stirling dependency acceptance. This is important because GitHub-hosted Windows already has a different ImageMagick build.
- Acceptance: primary Run `33092698357` (#67), job `98589465377`, commit `d1801e8569a23a762035a39dc7295de0f19e6115`; artifact `9655904308`, digest `sha256:f09b2d20d249c94a783ef129ec36bf9050d7ea7201f76122f0cf091606e27f83`.

### Ghostscript — accepted

- Version: `10.07.1` Win64.
- Official Artifex asset: `gs10071w64.exe` from release `gs10071`.
- SHA-256: `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`.
- Package root: `tools/ghostscript/`.
- The official NSIS asset is extracted with 7-Zip rather than executed, preventing installer/registry state from contaminating portability evidence.
- Official `bin/gswin64c.exe` is retained. A byte-identical package-local `bin/gs.exe` satisfies Stirling 2.14.3's literal `gs` probe.
- Validation requires PE AMD64, exact version, provenance/hashes, isolated package-first resolution, real PostScript -> PDF -> PNG conversion and Stirling backend dependency acceptance.
- **Acceptance:** primary Run `33104114920` (#68), job `98629258424`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004` passed the complete workflow with all prior gates still enabled. Artifact `9660338658` has Actions digest `sha256:843dfdad3def8072ced147ea3c208c01019ec397f0a5f49b3c5bfcbc47cda9cd`.

## Tesseract OCR Windows candidate — 2026-08-27

The active layer pins official **Tesseract release 5.5.3**, whose current Win64 installer embeds CLI build **5.5.3.20260724**.

- Official asset: `tesseract-ocr-w64-setup-5.5.3.20260724.exe`.
- Official GitHub SHA-256: `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`.
- The NSIS asset is extracted without executing the installer, so CI cannot inherit installer-created PATH, registry or uninstall state.
- 7-Zip exposes installer helper files under `$PLUGINSDIR`; PDF_Tunner removes that installer-only directory from the normalized portable runtime and validates that it does not survive.
- The upstream installer downloads languages dynamically from `tessdata_fast/main`; PDF_Tunner deliberately does **not** inherit that moving source.
- `tessdata_fast` is pinned to commit `87416418657359cb625c412a48b6e1d6d41c29bd`.
- Initial bundled models:
  - `eng.traineddata` Git blob `bbef4675053b5b468cdb477053e28b1c698ba08e`;
  - `spa.traineddata` Git blob `72e901f13ca52cfe34cf239a368b9ed3c0ddaf26`;
  - `osd.traineddata` Git blob `527457ca8f8fe1fda7c2f88bce3c0e4be12be9d0`.

`eng` is retained because Stirling's OCR guidance treats it as the base language. Spanish is included for the initial PDF_Tunner user-facing language set, and OSD is required for orientation/script detection. The package remains extensible to additional `.traineddata` models; bundling every upstream language is deferred until the final package-size trade-off is assessed together with LibreOffice and Calibre.

Run `33109977150` (#69), job `98649908490`, was a useful **diagnostic failure**, not an acceptance run. Every previously accepted tool and build gate passed through Ghostscript; Tesseract staging extracted the real runtime and downloaded the pinned models, then failed its first version assertion because the Windows binary reports `tesseract v5.5.3.20260724` while the initial gate expected the release-only form `tesseract 5.5.3`. Failure diagnostics also proved `$PLUGINSDIR` was being copied into `tools/tesseract/`.

The corrected staging/validation contract therefore keeps release identity (`5.5.3`) distinct from the exact Windows CLI build (`5.5.3.20260724`), derives the latter from the pinned immutable installer filename, records it as `CLI_VERSION` in provenance, requires the exact CLI build with an optional upstream `v` prefix, and removes/rejects `$PLUGINSDIR`.

`.github/scripts/prepare-tesseract.ps1` owns official installer download/hash verification, archive extraction, runtime normalization, exact CLI-build identification and exact tessdata commit/blob verification. `.github/scripts/validate-tesseract.ps1` independently requires:

- package-local AMD64 `tesseract.exe`;
- release `5.5.3` plus exact Windows CLI build `5.5.3.20260724` from provenance/source identity;
- `where tesseract` resolving the packaged executable from an isolated PATH;
- package-local `TESSDATA_PREFIX`;
- exact Git blob identities for `eng`, `spa`, `osd`;
- `--list-langs` containing all three models;
- real English OCR;
- real Spanish OCR;
- real OSD execution on a rotated image;
- Stirling backend logs accepting `tesseract` and explicitly reporting the package-local tessdata path;
- no downloaded installer or `$PLUGINSDIR` in the final product tree.

Tesseract remains a **candidate** until the complete primary Windows portable workflow passes with all previously accepted gates still enabled.

## Build and validation

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

During active development it has `workflow_dispatch` plus one temporary branch-scoped `push` trigger and a `concurrency` group with `cancel-in-progress: true`. The connector-readable Commit Status bridge is also development-only. Both the automatic push trigger and `.github/scripts/publish-push-run-statuses.ps1` must be removed before the final merge to `main`.

The permanent portable gate currently covers:

- pinned upstream ancestry;
- official Tauri/Cargo tests;
- production `PDF_Tunner.exe`;
- bundled Java 25;
- Fixed WebView2 static/live package selection and profile containment;
- accepted qpdf functional/provenance/backend checks;
- accepted ImageMagick functional/provenance/backend checks;
- accepted Ghostscript functional/provenance/backend checks;
- candidate Tesseract package/model pins, real OCR/OSD and backend tessdata-path acceptance;
- real backend startup and `/api/v1/info/status` HTTP 200;
- package-local Java temp;
- package-local Tauri stores/logs/cookies/window state;
- no new tracked host AppData/TEMP/protocol state;
- normal parent/child shutdown;
- deliberate two-launch Win32 window-state persistence/restore;
- final clean-tree revalidation;
- ZIP + SHA-256 + short-lived Actions artifact.

A tool is never considered accepted from `--version` alone. Where practical, each tool must perform a real operation while PATH/environment isolation proves the GitHub runner is not supplying a hidden dependency.

## Remaining v1 roadmap

The roadmap is cumulative. Completing the current candidate never means the rest of the project is complete.

1. **Complete the external toolchain:** Tesseract; OCRmyPDF; LibreOffice; UNO/Unoconvert; Poppler (`pdftohtml`, `pdfinfo`, `pdfimages`); portable Python; NumPy; OpenCV; WeasyPrint; Calibre; `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate `jbig2enc`; establish a viable portable RAR/CBR path or document the technical limitation; add any further exact dependency exposed by pinned Stirling source.
2. **Representative E2E operations:** OCR/OCRmyPDF, Office conversions, HTML/URL -> PDF, Poppler, WeasyPrint, Calibre/EPUB, Python/OpenCV, and representative Stirling API families.
3. **Non-Enterprise parity audit:** verify that intended Stirling 2.14.3 non-Enterprise functionality is actually available in the assembled portable product, not merely that the backend starts.
4. **Final branding audit:** executable, product/window strings, icons/logos, UI, metadata, ZIP/Release names and updater behavior.
5. **Final portability audit:** AppData, TEMP, registry, WebView2, Tauri state, each external tool's config/cache/temp state and orphan processes.
6. **CI/repository cleanup:** remove temporary push/status bridge and other development-only mechanisms; inspect final downstream diff and generated-output hygiene.
7. **Final docs/provenance:** versions, hashes, sources, accepted runs and reproducible validation record.
8. **Integrate to `main`:** only after all release gates; do not reopen/reuse the old closed PR #1 as the release vehicle.
9. **Publish v1 Release:** clean portable ZIP and final SHA/provenance only after release readiness.
10. **Manual Windows 10/11 validation:** clean extraction, startup, representative operations, portability and restart/cleanup checks on real hardware.

## Continuity protocol

To prevent project context from being lost between conversations, resumed PDF_Tunner work must follow these gates **before making repository changes**:

1. Recover the two most recent relevant PDF_Tunner conversations/work handoffs.
2. Read the current project prompt/rules plus `README.md` and `AGENTS.md`.
3. Verify the live branch HEAD, most recent primary Actions run, PR state and Release state.
4. Carry four explicit states: **accepted/closed**, **active candidate**, **next block**, **broader remaining roadmap**.
5. Never use “the next task is X” to imply X is the only remaining work.
6. At each accepted milestone record the commit, Run/job, artifact/digest when relevant, next candidate and remaining roadmap in the permanent documentation.
7. Before any final Release, audit against the **full original PDF_Tunner objective**, not only the most recently completed tool.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same commit.**

The detailed diagnostic chronology that led to the accepted architecture remains preserved in git history; these files prioritize the current operational contract, accepted evidence, active candidate and complete remaining roadmap so a new conversation can resume safely.
