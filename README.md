# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a GitHub fork of Stirling PDF: the project tunes that fork directly rather than rebuilding Stirling behind a separate wrapper.

## Base and status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Initial upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- Status: **portable bootstrap green; Run #50 identified three real Tauri-profile leaks (`.cookies`, `PDF_Tunner.log`, `connection.json`); the current downstream fix redirects all three under package `data/` and awaits the new two-launch CI proof before this layer is declared green; no final Release yet**

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

WebView2 receives the component-specific override `WEBVIEW2_USER_DATA_FOLDER=<portable root>\data\webview2`. Run #15 proved this is effective in the packaged production executable: the profile was populated with 122 files (about 4.6 MB) while Stirling started normally on a dynamic backend port. CI therefore requires a populated `data/webview2` profile and specifically checks that the default host `EBWebView` directory is not newly created under `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView`.

`tauri-plugin-window-state` 2.2.1 cannot be pointed at a portable directory: it always writes through Tauri's `app_config_dir()` (Roaming AppData). PDF_Tunner therefore keeps the official plugin unchanged outside portable mode, but portable mode substitutes a localized equivalent under `data/tauri/window-state/.window-state.json`. The replacement keeps the upstream state shape (`width`, `height`, `x`, `y`, `prev_x`, `prev_y`, `maximized`, `visible`, `decorated`, `fullscreen`), tracks primary and dynamically-created windows, avoids restoring a saved rectangle that no longer intersects an available monitor, captures the last window before it disappears, and saves the state before PDF_Tunner's terminal `cleanup_before_exit()`/`process::exit()` sequence.

Run #50 proved that mere directory classification was not the remaining issue. Its diagnostic artifact showed three real native Tauri persistence leaks:

- `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\.cookies` from `tauri-plugin-http` 2.5.8, whose cookie feature unconditionally creates `.cookies` under Tauri `app_cache_dir()` during plugin setup;
- `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\logs\PDF_Tunner.log` from the default `tauri-plugin-log` 2.8.0 `LogDir` target;
- `%APPDATA%\com.willsitogg.pdf-tunner\connection.json` from `tauri-plugin-store` 2.4.2 resolving the relative `connection.json` path against Tauri `BaseDirectory::AppData`.

The portable fix is component-specific and leaves non-portable Stirling behavior unchanged:

- `tauri-plugin-log` uses its supported `TargetKind::Folder` only in portable mode and writes `data/tauri/logs/PDF_Tunner.log`; normal mode keeps the upstream/default `LogDir` behavior;
- the connection store keeps the same `connection.json` store API, but its path resolves to `data/tauri/store/connection.json` only when `PDF_TUNNER_PORTABLE_ROOT` exists; normal mode remains the relative `connection.json` path;
- `tauri-plugin-http` 2.5.8 exposes no public cookie-jar path override, so PDF_Tunner vendors that exact plugin source locally with one downstream portability change: portable mode uses `data/tauri/http/.cookies`, while non-portable mode still calls Tauri `app_cache_dir()`. Cookie persistence and the HTTP client remain enabled.

This is deliberately not a post-shutdown cleanup workaround. The state is created at the package-local destinations in the first place.

The two-launch Win32 validator now starts by deleting both `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` and `%APPDATA%\com.willsitogg.pdf-tunner` **before any validation launch** to establish a known-zero host baseline. It then requires the package-local HTTP cookie jar, Tauri log and connection store, performs the deliberate window move/resize and package-local window-state save, relaunches the same assembled production executable, verifies geometry restoration and fails if either Windows profile root contains any file or subdirectory after either launch. An otherwise empty identifier directory is recorded but is not misclassified as persisted state. No host-profile cleanup occurs after launch to make the test pass.

Bundled tool directories are prepended to `PATH` only when present, packaged Tesseract data is exposed through `TESSDATA_PREFIX` when available, and Calibre configuration is pointed at `data/calibre/`. Runtime deep-link protocol registration is skipped in portable mode to avoid writing the `pdf-tunner://` handler into the host OS registry.

Portable shutdown handles `ExitRequested` synchronously: it saves portable window state, terminates the bundled Java backend, calls Tauri's `cleanup_before_exit()`, and finally exits the process immediately with the requested exit code. This follows Tauri's contract for manual cleanup: after `cleanup_before_exit()` returns, the process must terminate immediately and no further Tauri APIs may be used. Run #11 proved that merely waiting for a later `RunEvent::Exit` after backend cleanup can leave the Windows portable parent alive. Non-portable upstream behavior remains unchanged.

Intended current layout:

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
      http/
        .cookies
      logs/
        PDF_Tunner.log
      store/
        connection.json
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

During active development it has `workflow_dispatch` plus one temporary automatic `push` trigger restricted to `pdf-tunner/windows-portable-v1`. The duplicate `pull_request` trigger was removed after the run-queue incident because it caused the same heavy portable validation to be enqueued twice and also woke inherited Stirling PR workflows. The workflow uses a branch-scoped `concurrency` group with `cancel-in-progress: true`. The development `push` trigger must still be removed before the final change reaches `main`; the intended permanent state is manual `workflow_dispatch`.

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
- package-local `data/tauri/http/.cookies`, `data/tauri/logs/PDF_Tunner.log`, `data/tauri/store/connection.json` and `data/tauri/window-state/.window-state.json`;
- a clean pre-launch baseline for both `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` and `%APPDATA%\com.willsitogg.pdf-tunner`, followed by hard failure on any file/subdirectory recreated there by either validator launch;
- no new `HKCU\Software\Classes\pdf-tunner` protocol registration during portable startup/shutdown;
- two-launch window-state geometry persistence/restore;
- clean parent/child-process shutdown;
- clean ZIP generation;
- SHA-256 generation.

Window-state and Tauri-profile containment proof are part of the primary portable workflow. `.github/scripts/validate-portable-window-state.ps1` runs against the same assembled production executable before CI clears generated `data/` and creates the final ZIP. It performs two real launches and does not remove host state between or after those launches.

If the real packaged-startup smoke test fails, CI writes host-temp/profile/registry/process evidence **before** touching potentially locked browser files. It records a recursive host application-tree inventory, a file-count/size/sample summary for the live package-local WebView2 profile and copies logs/configs/temp/pipeline/Tauri state best-effort, but deliberately does not recursively copy `data/webview2` while Chromium may still own locked files. Diagnostic artifact upload explicitly includes hidden files so `.window-state.json` and `.cookies` are preserved when present. The resulting `PDF_Tunner-startup-diagnostics` artifact is short-lived diagnostic evidence only, not a Release asset.

Diagnostic run #9 proved the production EXE initializes Tauri, uses package-local data/log/config paths, launches bundled Java 25, starts Stirling 2.14.3 on a dynamic loopback port, answers the real health endpoint and terminates the Java backend during close. It also exposed Java temporary state in host `%LOCALAPPDATA%\Temp` and a parent-process shutdown defect.

Diagnostic run #11 then proved the Java-temp fix and host-integration containment: both `stirling-pdf` and `stirling-mobile-scanner` temporary directories were created under package `data/tmp`, no new corresponding host `%TEMP%` directories appeared, the `HKCU\Software\Classes\pdf-tunner` protocol key remained absent, and Java/child processes terminated. Its only remaining failure was that the Tauri parent stayed alive after `ExitRequested`.

Run #13 closed that bootstrap defect. The complete portable job passed real startup, backend health, local Java temp, registry containment, normal parent shutdown, child cleanup, runtime-data cleanup, ZIP creation and SHA-256 generation.

Run #15 proved the new WebView2 redirection itself: the packaged app created a real browser profile under `data/webview2` (122 files, about 4.6 MB) and the backend reached `Stirling-PDF running on port: 57658`.

Run #19 passed the portable build on the first integrated custom window-state implementation: official desktop preparation/tests, production EXE build, portable assembly, bundled JRE validation, real backend startup/health, Java-temp and WebView2 containment, normal parent/child shutdown, runtime-data reset, ZIP/SHA-256 and artifact upload all completed successfully.

Run #49 was the first execution of the deliberate two-launch geometry validator. All pre-validator checks passed and the first validator launch wrote `data/tauri/window-state/.window-state.json`; it stopped before the second launch when the then-current test classified the Roaming identifier root by existence rather than contents.

Run #50, on commit `52fb5502e3c8c753357aba95415326dfe30ca7cf`, added recursive profile diagnostics and proved the root was **not** merely empty: the artifact contained `.cookies` and `logs/PDF_Tunner.log` under LocalAppData plus `connection.json` under Roaming AppData. Those three files are the basis for the current source-level redirections and the expanded Local+Roaming two-launch validator. This change is not considered complete until the new staging/final workflow run executes the second launch, restores geometry, leaves both host profile roots without content and still produces the final ZIP artifact.

The general upstream `Build and Test Workflow` on the run #13 baseline passed frontend validation/a11y, stubbed and live Playwright, database migration, Docker Compose/images and the official Windows Tauri build. Its sole failure is GitHub `dependency-review`, which reports that Dependency Graph is disabled on this fork; that is a repository security-setting prerequisite rather than a demonstrated PDF_Tunner code regression.

After portable window-state/profile containment is proven, the next native dependency layer is the already-isolated Fixed WebView2 Runtime work. Do not integrate that branch until this layer is green.

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
