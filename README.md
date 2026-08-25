# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a GitHub fork of Stirling PDF: the project tunes that fork directly rather than rebuilding Stirling behind a separate wrapper.

## Base and status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Initial upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- Status: **AppData containment is CI-proven. Fixed WebView2 Runtime `151.0.4129.101` x64 is now pinned for staging to the verified Microsoft CDN CAB with SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`; full assembled-package acceptance is the current gate.**

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

The Tauri-side `add_log()` path is explicitly redirected to `data/logs/` in portable mode, preventing creation of `%APPDATA%\Stirling-PDF\logs`. The registered `tauri-plugin-log` file target is also replaced only in portable mode: stdout is retained and the default Windows `app_log_dir()` target under `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\logs` is replaced by `data/logs/tauri/`. Java temporary storage is isolated without changing native Windows `TEMP/TMP`: portable bootstrap sets Java-specific `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=...` so Stirling's normal temporary manager resolves under `data/tmp/stirling-pdf/` and the mobile-scanner service under `data/tmp/stirling-mobile-scanner/`.

WebView2 receives the component-specific override `WEBVIEW2_USER_DATA_FOLDER=<portable root>\data\webview2`. Run #15 proved this is effective in the packaged production executable: the profile was populated with 122 files (about 4.6 MB) while Stirling started normally on a dynamic backend port. CI therefore requires a populated `data/webview2` profile and specifically checks that the default host `EBWebView` directory is not newly created under `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView`. The parent `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` directory is inventoried separately rather than treated as WebView2 evidence, because other native Tauri state may use the same application identifier.

`tauri-plugin-window-state` 2.2.1 cannot be pointed at a portable directory: it always writes through Tauri's `app_config_dir()` (Roaming AppData). PDF_Tunner therefore keeps the official plugin unchanged outside portable mode, but portable mode substitutes a localized equivalent under `data/tauri/window-state/.window-state.json`. The replacement keeps the upstream state shape (`width`, `height`, `x`, `y`, `prev_x`, `prev_y`, `maximized`, `visible`, `decorated`, `fullscreen`), avoids restoring a saved rectangle that no longer intersects an available monitor, captures the last window before it disappears, and saves the state before PDF_Tunner's terminal `cleanup_before_exit()`/`process::exit()` sequence. Run #50 proved that the first launch really writes the requested measured geometry package-locally (client 824x581 at x=111/y=87), but the second launch did not restore it. Run `32634578447` then identified the concrete cause: the custom `on_window_ready` hook received a valid native `tauri::Window`, but attempted to re-resolve it immediately with `get_webview_window("main")`; at that lifecycle point the corresponding `WebviewWindow` was not yet discoverable, so the log recorded `Portable window-state window-ready hook could not resolve WebviewWindow 'main'` and no restore/listener was attached. The official plugin operates directly on the native `Window<R>` passed to `on_window_ready`. The current candidate now does the same, including upstream-compatible default visibility/decorations and size-before-position restore ordering. Run `32825188381` proved this correction on the assembled production EXE: the deliberate first-launch geometry was persisted package-locally and restored on the second launch within validator tolerance.

Run #50 and subsequent diagnostics proved that Stirling desktop state uses several `tauri-plugin-store` paths. The connection module's `connection.json` is package-local at `data/tauri/store/connection.json` in portable mode. Run `32634578447` proved that localization and the Tauri logger redirection both pass the real packaged startup smoke test. Its failure diagnostics then exposed `%APPDATA%\com.willsitogg.pdf-tunner\tokens.json`, created by the authentication fallback store when Windows keyring entries are absent/cleared, plus a second relative `connection.json` path used by auth user-info functions. The current candidate resolves both auth stores to `data/tauri/store/` only in portable mode while retaining the original relative AppData behavior outside portable mode; authentication/keyring logic itself is unchanged.

`tauri-plugin-http` 2.5.8 remains enabled with its normal cookie/authentication behavior. PDF_Tunner vendors the verified official `http-v2.5.8` source locally and changes only the persistent cookie directory selection: portable mode resolves `.cookies` under `data/tauri/http/`, while non-portable mode keeps the official Tauri `app_cache_dir()` behavior. Run `32825188381` proved the package-local cookie jar together with the other Tauri state and found no non-empty PDF_Tunner identifier content in host Local or Roaming AppData. The Windows keyring/Credential Manager path used by authentication remains keyring-first and is not claimed to be package-contained; the Tauri Store fallback is package-local.

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
    logs/
      tauri/
    tauri/
      store/
        connection.json
        tokens.json
      window-state/
        .window-state.json
      http/
        .cookies
```

`data/` contains runtime state and must not be committed. Run `32825188381` CI-proved the `data/tauri/http/.cookies`, `data/logs/tauri/`, `data/tauri/store/` and `data/tauri/window-state/` locations on the assembled portable package.

### AppData containment proof — Run `32825188381`

The clean candidate `f088d0ad288a21d6419ff94b35c0f76b9667e7d5` passed the complete Windows portable workflow. The job proved official Tauri/Cargo tests, a production `PDF_Tunner.exe`, bundled JRE 25, real dynamic-port backend health, package-local HTTP cookie jar/log/store/window state, deliberate window-state persistence plus second-launch restoration, no non-empty PDF_Tunner identifier state in host Local/Roaming AppData, no new `pdf-tunner://` protocol registration, clean parent/child shutdown, runtime-data reset, ZIP creation, SHA-256 generation and artifact upload. The validated artifact was `PDF_Tunner-Windows-x64-Portable-bootstrap` (Actions artifact `9555320194`).

## Fixed WebView2 Runtime staging

The Fixed WebView2 layer is pinned to Microsoft WebView2 Fixed Version Runtime **151.0.4129.101 x64**. Microsoft subsequently advanced the live developer-page API to newer 151 builds, so PDF_Tunner no longer scrapes mutable page controls for this historical target. The staging workflow pins the exact official Microsoft CDN CAB URL and requires SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda` before extraction.

Diagnostic Run `32853225739` independently downloaded that CAB from `msedge.sf.dl.delivery.mp.microsoft.com`, measured **307,241,094 bytes**, recalculated the same SHA-256, expanded **257 files**, found exactly one `msedgewebview2.exe`, and verified ProductVersion **151.0.4129.101**. The staging preparation script additionally rejects non-HTTPS/non-approved CDN hosts, a filename that is not exactly `Microsoft.WebView2.FixedVersionRuntime.151.0.4129.101.x64.cab`, delta markers, hash mismatch, missing runtime executable, or an unexpected product version.

The normalized runtime is staged at `runtime/webview2/fixed/`; provenance is written to `runtime/webview2/PROVENANCE.txt`. `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` selects this package-local runtime while the already-proven `WEBVIEW2_USER_DATA_FOLDER` keeps browser state under `data/webview2`. Windows 10 AppContainer ACL and network-location checks remain part of the runtime/launch validation before this phase can be called accepted.

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

The connected GitHub wrapper currently exposes pull-request-triggered workflow runs through its commit-run lookup but cannot enumerate `push` runs directly. PDF_Tunner therefore publishes a connector-readable Commit Status from the primary Windows portable workflow itself. Immediately after checkout, `.github/scripts/publish-push-run-statuses.ps1` records the current `GITHUB_RUN_ID` and queries recent `push` runs for the same workflow, backfilling their head commits with status context `pdf-tunner/windows-portable-push`. Each status carries the run number/result in its description and the exact Actions run URL in `target_url`. The connector can read that status through its existing commit-status endpoint and then inspect jobs, logs and artifacts normally. This adds no second workflow/job, performs no repository writes, and requires only `actions: read` plus `statuses: write`; the development-only bridge must be removed before final merge to `main`.

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
- no non-empty persisted PDF_Tunner identifier content under host `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` or `%APPDATA%\com.willsitogg.pdf-tunner` in portable mode;
- package-local Tauri connection/user-info/token stores and Tauri log state rather than Roaming `connection.json`/`tokens.json` or LocalAppData Tauri log files;
- inventory of other PDF_Tunner/Stirling app-specific host folders so Tauri/plugin state is classified separately from WebView2;
- no new `HKCU\Software\Classes\pdf-tunner` protocol registration during portable startup/shutdown;
- clean parent/child-process shutdown;
- clean ZIP generation;
- SHA-256 generation.

Run `32825188381` closed the tracked native Tauri AppData containment set, including the HTTP `.cookies` jar. This closes the AppData phase, not the entire portable-v1 project: Fixed WebView2 Runtime and the external dependency toolchain still require their own proof.

Window-state proof is part of the primary portable workflow. After the first real startup/backend/containment smoke test, `.github/scripts/validate-portable-window-state.ps1` establishes a clean `%APPDATA%\com.willsitogg.pdf-tunner` baseline, launches the same assembled production executable, deliberately moves/resizes its real Win32 top-level window, closes normally, checks `data/tauri/window-state/.window-state.json` against the measured outer position/client size, relaunches the same portable tree, verifies restoration within tolerance, checks child-process cleanup and fails if any actual Roaming-AppData content is persisted. Only after that proof does CI clear generated `data/`, create the final portable ZIP and generate its SHA-256.

If the real packaged-startup smoke test fails, CI writes host-temp/profile/registry/process evidence **before** touching potentially locked browser files. It records a recursive host application-tree inventory, a file-count/size/sample summary for the live package-local WebView2 profile and copies logs/configs/temp/pipeline/Tauri state best-effort, but deliberately does not recursively copy `data/webview2` while Chromium may still own locked files. Diagnostic artifact upload explicitly includes hidden files so `.window-state.json` is preserved when present. The resulting `PDF_Tunner-startup-diagnostics` artifact is short-lived diagnostic evidence only, not a Release asset.

Diagnostic run #9 proved the production EXE initializes Tauri, uses package-local data/log/config paths, launches bundled Java 25, starts Stirling 2.14.3 on a dynamic loopback port, answers the real health endpoint and terminates the Java backend during close. It also exposed Java temporary state in host `%LOCALAPPDATA%\Temp` and a parent-process shutdown defect.

Diagnostic run #11 then proved the Java-temp fix and host-integration containment: both `stirling-pdf` and `stirling-mobile-scanner` temporary directories were created under package `data/tmp`, no new corresponding host `%TEMP%` directories appeared, the `HKCU\Software\Classes\pdf-tunner` protocol key remained absent, and Java/child processes terminated. Its only remaining failure was that the Tauri parent stayed alive after `ExitRequested`.

Run #13 closed that bootstrap defect. The complete portable job passed real startup, backend health, local Java temp, registry containment, normal parent shutdown, child cleanup, runtime-data cleanup, ZIP creation and SHA-256 generation. The independently inspected bootstrap ZIP contained the expected executable, Stirling 2.14.3 JAR and bundled Java runtime and matched its published SHA-256.

Run #15 then proved the new WebView2 redirection itself: the packaged app created a real browser profile under `data/webview2` (122 files, about 4.6 MB) and the backend reached `Stirling-PDF running on port: 57658`. Its smoke step failed before shutdown because the first containment assertion watched the entire `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` application root, which is broader than the WebView2 default `EBWebView` path. The failure diagnostics also exposed that recursively copying a live Chromium profile can abort on locked files. Both test-design issues were corrected without weakening the actual WebView2 containment requirement.

Run #19 passed the portable build on the first integrated custom window-state implementation: official desktop preparation/tests, production EXE build, portable assembly, bundled JRE validation, real backend startup/health, Java-temp and WebView2 containment, normal parent/child shutdown, runtime-data reset, ZIP/SHA-256 and artifact upload all completed successfully. Run #19 proves the custom portable state layer does not regress bootstrap.

Run #49 was the first execution of the deliberate two-launch geometry validator. All build, official Tauri/Cargo, bundled-JRE, production-startup, backend-health, Java-temp, WebView2 and shutdown steps passed. The first validator launch moved/resized and closed normally, and the diagnostics proved `data/tauri/window-state/.window-state.json` was written. The validator stopped before its second launch because its then-current assertion treated existence of `%APPDATA%\com.willsitogg.pdf-tunner` itself as state; that test-design defect was corrected to inspect actual contents.

Run #50 (`run_id 32582638502`) then reached the genuine second-launch proof. The first launch measured client 824x581 at x=111/y=87 and saved exactly those values package-locally. On relaunch the main window appeared around 1028x749 at x=0/y=0, so restore failed. Inspection confirmed neither the base nor PDF_Tunner Tauri config imposes a main-window minimum that would invalidate 824x581.

Push run `32634578447` on commit `eb010bc84e09b57964053530614ff66828a9b3c7` passed official desktop preparation/tests, production Tauri build, portable assembly, bundled Java 25 and the complete real backend/containment smoke step, proving the package-local connection store and Tauri log target at runtime. Its two-launch validator still failed, and the uploaded diagnostics finally exposed the exact lifecycle bug: both launches logged that the `on_window_ready` hook could not resolve `WebviewWindow 'main'`. The package-local state file still held the requested first-launch geometry 824x581 at x=111/y=87. The same diagnostics exposed a two-byte Roaming `tokens.json` auth fallback store. The current candidate therefore restores/listens directly on the native `Window<R>` supplied by `on_window_ready`—as upstream 2.2.1 does—and localizes both auth fallback stores. **Neither correction is accepted until the next production CI run proves it.**

The earlier push run `32598488359` failed in startup containment even though its diagnostics proved the Java backend started correctly on port 53150 and shut down cleanly. Its actual failure was `%APPDATA%\com.willsitogg.pdf-tunner\connection.json`; the artifact also classified `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\logs\PDF_Tunner.log` as the default `tauri-plugin-log` target and `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\.cookies` as `tauri-plugin-http`'s native cookie jar. The connection/log host writes have since been proven fixed by run `32634578447`; the HTTP cookie jar remains pending.

The general upstream `Build and Test Workflow` on the run #13 baseline passed frontend validation/a11y, stubbed and live Playwright, database migration, Docker Compose/images and the official Windows Tauri build. Its sole failure is GitHub `dependency-review`, which reports that Dependency Graph is disabled on this fork; that is a repository security-setting prerequisite rather than a demonstrated PDF_Tunner code regression. Each subsequent downstream commit is checked again for additional failures before it is accepted.

The native HTTP cookie localization and AppData-containment phase are proven. The current candidate now stages the independently verified Fixed WebView2 Runtime 151.0.4129.101 x64 using a pinned Microsoft CDN URL and SHA-256. Acceptance still requires the heavy staging workflow to prove runtime selection, Windows 10-compatible ACL handling, network-location rejection, backend health, portable state containment, two-launch window restore and clean shutdown on the assembled production tree.

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
