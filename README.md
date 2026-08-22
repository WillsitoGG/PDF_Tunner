# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a GitHub fork of Stirling PDF: the project tunes that fork directly rather than rebuilding Stirling behind a separate wrapper.

## Base and status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Initial upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- Status: **portable bootstrap green; WebView2 profile redirection proven; run #49 proved package-local window-state save and isolated the remaining two-launch validation issue to Roaming-AppData classification before the second launch; no final Release yet**

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

The first packaged-startup CI diagnostics showed that globally replacing Windows profile variables (`APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` and `TMP`) before Tauri initialization caused the executable to terminate before Tauri setup/backend logging began. Portable mode therefore uses a narrower boundary: it sets component-specific overrides while leaving the Windows profile seen by native infrastructure intact. Stirling's centralized `app_data_dir()` redirects backend configuration, logs and working state to package-local `data/`; portable system provisioning is likewise resolved under `data/provisioning/`.

The Tauri-side `add_log()` path is explicitly redirected to `data/logs/` in portable mode, preventing creation of `%APPDATA%\Stirling-PDF\logs`. Java temporary storage is isolated without changing native Windows `TEMP/TMP`: portable bootstrap sets Java-specific `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=...` so Stirling's normal temporary manager resolves under `data/tmp/stirling-pdf/` and the mobile-scanner service under `data/tmp/stirling-mobile-scanner/`.

WebView2 receives the component-specific override `WEBVIEW2_USER_DATA_FOLDER=<portable root>\data\webview2`. Run #15 proved this is effective in the packaged production executable: the profile was populated with 122 files (about 4.6 MB) while Stirling started normally on a dynamic backend port. CI therefore requires a populated `data/webview2` profile and specifically checks that the default host `EBWebView` directory is not newly created under `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView`. The parent `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` directory is inventoried separately rather than treated as WebView2 evidence, because other native Tauri state may use the same application identifier.

`tauri-plugin-window-state` 2.2.1 cannot be pointed at a portable directory: it always writes through Tauri's `app_config_dir()` (Roaming AppData). PDF_Tunner therefore keeps the official plugin unchanged outside portable mode, but portable mode substitutes a localized equivalent under `data/tauri/window-state/.window-state.json`. The replacement keeps the upstream state shape (`width`, `height`, `x`, `y`, `prev_x`, `prev_y`, `maximized`, `visible`, `decorated`, `fullscreen`), tracks primary and dynamically-created windows, avoids restoring a saved rectangle that no longer intersects an available monitor, captures the last window before it disappears, and saves the state before PDF_Tunner's terminal `cleanup_before_exit()`/`process::exit()` sequence. The primary Windows portable workflow runs a two-launch Win32 validator against the assembled production portable tree before runtime data is reset and the final ZIP is created. Run #49 proved that the first launch writes the package-local state file and closes the backend/process tree normally. Its failure occurred before the second launch because the validator treated mere existence of `%APPDATA%\com.willsitogg.pdf-tunner` as persisted state. The revised proof starts from a deleted baseline and hard-fails on any file or subdirectory there, while distinguishing a completely empty native identifier directory from actual persisted Roaming state.

The registered `tauri-plugin-store` currently has no application call sites in this fork and remains registered for upstream compatibility. Any future relative store use must be audited because Tauri resolves it through AppData unless explicitly localized.

Bundled tool directories are prepended to `PATH` only when present, packaged Tesseract data is exposed through `TESSDATA_PREFIX` when available, and Calibre configuration is pointed at `data/calibre/`. Runtime deep-link protocol registration is skipped in portable mode to avoid writing the `pdf-tunner://` handler into the host OS registry.

Portable shutdown handles `ExitRequested` synchronously: it saves portable window state, terminates the bundled Java backend, calls Tauri's `cleanup_before_exit()`, and finally exits the process immediately with the requested exit code. This follows Tauri's contract for manual cleanup: after `cleanup_before_exit()` returns, the process must terminate immediately and no further Tauri APIs may be used. Run #11 proved that merely waiting for a later `RunEvent::Exit` after backend cleanup can leave the Windows portable parent alive. Non-portable upstream behavior remains unchanged.

Intended final layout:

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  libs/
  runtime/jre/
  tools/
  data/
    webview2/
    tauri/
      window-state/
        .window-state.json
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

Primary build workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

During active development it has `workflow_dispatch` plus one temporary automatic `push` trigger restricted to `pdf-tunner/windows-portable-v1`. The duplicate `pull_request` trigger was removed after the run-queue incident because it caused the same heavy portable validation to be enqueued twice and also woke inherited Stirling PR workflows. The workflow now uses a branch-scoped `concurrency` group with `cancel-in-progress: true`, so a newer commit supersedes an older portable run instead of accumulating obsolete jobs. The development `push` trigger must still be removed before the final change reaches `main`; the intended permanent state is manual `workflow_dispatch`.

Bootstrap validation currently targets:

- documented upstream-base ancestry;
- official Tauri/Cargo tests;
- production Tauri executable;
- bundled Java 25 runtime;
- package-local portable marker/data paths;
- real Java backend startup and dynamic port detection;
- `/api/v1/info/status` health response;
- Java temporary paths under `data/tmp/`, with no new `stirling-pdf` or `stirling-mobile-scanner` directories created in host `%TEMP%`;
- WebView2 user data under `data/webview2/`, with no new `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView` profile;
- no persisted files/subdirectories under `%APPDATA%\com.willsitogg.pdf-tunner` in portable mode; an otherwise empty identifier directory is recorded but is not misclassified as state;
- inventory of other PDF_Tunner/Stirling app-specific host folders so Tauri/plugin state is classified separately from WebView2;
- no new `HKCU\Software\Classes\pdf-tunner` protocol registration during portable startup/shutdown;
- clean parent/child-process shutdown;
- clean ZIP generation;
- SHA-256 generation.

Window-state proof is part of the primary portable workflow. After the first real startup/backend/containment smoke test, `.github/scripts/validate-portable-window-state.ps1` establishes a clean `%APPDATA%\com.willsitogg.pdf-tunner` baseline, launches the same assembled production executable, deliberately moves/resizes its real Win32 top-level window, closes normally, checks `data/tauri/window-state/.window-state.json` against the measured outer position/client size, relaunches the same portable tree, verifies restoration within tolerance, checks child-process cleanup and fails if any actual Roaming-AppData content is persisted. Only after that proof does CI clear generated `data/`, create the final portable ZIP and generate its SHA-256.

If the real packaged-startup smoke test fails, CI writes host-temp/profile/registry/process evidence **before** touching potentially locked browser files. It records a recursive host application-tree inventory, a file-count/size/sample summary for the live package-local WebView2 profile and copies logs/configs/temp/pipeline/Tauri state best-effort, but deliberately does not recursively copy `data/webview2` while Chromium may still own locked files. Diagnostic artifact upload explicitly includes hidden files so `.window-state.json` is preserved when present. The resulting `PDF_Tunner-startup-diagnostics` artifact is short-lived diagnostic evidence only, not a Release asset.

Diagnostic run #9 proved the production EXE initializes Tauri, uses package-local data/log/config paths, launches bundled Java 25, starts Stirling 2.14.3 on a dynamic loopback port, answers the real health endpoint and terminates the Java backend during close. It also exposed Java temporary state in host `%LOCALAPPDATA%\Temp` and a parent-process shutdown defect.

Diagnostic run #11 then proved the Java-temp fix and host-integration containment: both `stirling-pdf` and `stirling-mobile-scanner` temporary directories were created under package `data/tmp`, no new corresponding host `%TEMP%` directories appeared, the `HKCU\Software\Classes\pdf-tunner` protocol key remained absent, and Java/child processes terminated. Its only remaining failure was that the Tauri parent stayed alive after `ExitRequested`.

Run #13 closed that bootstrap defect. The complete portable job passed real startup, backend health, local Java temp, registry containment, normal parent shutdown, child cleanup, runtime-data cleanup, ZIP creation and SHA-256 generation. The independently inspected bootstrap ZIP contained the expected executable, Stirling 2.14.3 JAR and bundled Java runtime and matched its published SHA-256.

Run #15 then proved the new WebView2 redirection itself: the packaged app created a real browser profile under `data/webview2` (122 files, about 4.6 MB) and the backend reached `Stirling-PDF running on port: 57658`. Its smoke step failed before shutdown because the first containment assertion watched the entire `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` application root, which is broader than the WebView2 default `EBWebView` path. The failure diagnostics also exposed that recursively copying a live Chromium profile can abort on locked files. Both test-design issues were corrected without weakening the actual WebView2 containment requirement.

Run #19 passed the portable build on the first integrated custom window-state implementation: official desktop preparation/tests, production EXE build, portable assembly, bundled JRE validation, real backend startup/health, Java-temp and WebView2 containment, normal parent/child shutdown, runtime-data reset, ZIP/SHA-256 and artifact upload all completed successfully. Run #19 proves the custom portable state layer does not regress bootstrap.

Run #49 was the first execution of the deliberate two-launch geometry validator. All build, official Tauri/Cargo, bundled-JRE, production-startup, backend-health, Java-temp, WebView2 and shutdown steps passed. The first validator launch moved/resized and closed normally, and the diagnostics prove `data/tauri/window-state/.window-state.json` was written. The validator stopped before its second launch because `%APPDATA%\com.willsitogg.pdf-tunner` existed after the first close. The run-49 artifact recorded only root existence, not recursive contents, so the next revision correctly distinguishes an empty identifier directory from actual state and captures the full host tree plus hidden portable state on any failure.

The general upstream `Build and Test Workflow` on the run #13 baseline passed frontend validation/a11y, stubbed and live Playwright, database migration, Docker Compose/images and the official Windows Tauri build. Its sole failure is GitHub `dependency-review`, which reports that Dependency Graph is disabled on this fork; that is a repository security-setting prerequisite rather than a demonstrated PDF_Tunner code regression. Each subsequent downstream commit is checked again for additional failures before it is accepted.

After portable window-state is proven, the next native dependency layer is a bundled Fixed WebView2 Runtime. Microsoft currently lists x64 runtime 151.0.4129.101 (20 August 2026); the integration must use `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER`, retain `WEBVIEW2_USER_DATA_FOLDER`, handle Windows 10 Fixed Version 120+ AppContainer read/execute ACL requirements, reject UNC/network execution, and verify the packaged runtime rather than any Evergreen runtime already installed on the CI host.

The following validation layers will then integrate every external dependency and representative end-to-end Stirling operation before any final Release is published.

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