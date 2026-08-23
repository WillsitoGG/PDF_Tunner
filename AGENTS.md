# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. These rules override generic cleanup conventions when those conventions would make the Stirling fork harder to compare or synchronize upstream.

## Project identity

PDF_Tunner is the real GitHub fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

Target:

- Windows 10/11 x64;
- portable ZIP: extract and run;
- application/binary name `PDF_Tunner`;
- retain Stirling functionality except functionality specifically belonging to Enterprise/SaaS offerings;
- bundle required runtimes and external conversion/OCR tools whenever technically viable;
- keep configuration, caches, logs, temporary files and runtime state inside the portable tree as far as the underlying Windows APIs allow;
- remain straightforward to diff/rebase/update from upstream.

## Pinned starting point

- Upstream: `Stirling-Tools/Stirling-PDF`
- Version: `2.14.3`
- Initial commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Java: 25
- Development branch: `pdf-tunner/windows-portable-v1`

Record any future upstream update here and in README before treating it as the new base.

## Mandatory repository rules

1. Preserve Stirling's root structure. Do not reorganize this fork into generic root-level `Archive/`, `Source/` or `Validation/` trees.
2. Keep `main` clean: no build outputs, logs, abandoned experiments, one-shot triggers or temporary scripts.
3. Prefer small, localized downstream deltas.
4. Preserve upstream behavior unless the user explicitly requests removal or the functionality is specifically outside the PDF_Tunner target.
5. Compilation alone is never validation. Test the assembled portable application and relevant operations.
6. Never archive failed/intermediate builds as history.
7. Preserve historical git tags; only final published packages count as release history.
8. SHA-256/provenance belongs in repository validation records rather than miscellaneous Release assets unless a final packaging decision says otherwise.
9. **Every PDF_Tunner-specific change must modify both `README.md` and `AGENTS.md` in the same commit.**
10. Do not make licensing the center of technical work. Mention it only when it creates a concrete implementation/distribution constraint.
11. Heavy repeated CI must use a branch/workflow-specific `concurrency` group with `cancel-in-progress: true`; do not allow obsolete portable runs to pile up.
12. During active downstream development use at most one automatic trigger for the heavy portable workflow unless duplicate events are technically necessary and deduplicated.

## Architecture decision

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`.

Do not restore the old `PDF_Tunner_Legacy` architecture in which a separate .NET WinForms/WebView2 launcher started a Stirling JAR. The legacy repository is reference material only.

Useful legacy ideas retained:

- portable profile/data redirection where it is safe for the owning component;
- bundled Java;
- loopback-only backend;
- readiness checks;
- process-tree cleanup;
- reproducible ZIP + SHA-256;
- explicit dependency/version checks.

Current upstream Tauri already owns single-instance handling, file opening, drag/drop, WebView lifecycle, dynamic backend-port discovery and backend cleanup. Preserve those mechanisms unless a portable-specific defect is demonstrated.

## Desktop/JRE facts

`.taskfiles/desktop.yml` is the authoritative desktop build path. At the pinned base it:

- builds the desktop backend boot JAR;
- bundles host-appropriate JPDFium natives;
- builds a Java 25 JRE with JLink;
- includes `jdk.dynalink` for VeraPDF;
- includes `jdk.crypto.mscapi` on Windows;
- stages the JAR in `frontend/editor/src-tauri/libs`;
- stages the JRE in `frontend/editor/src-tauri/runtime/jre`;
- exposes Tauri/Cargo tests via `task desktop:test`.

The official desktop task currently sets `DISABLE_ADDITIONAL_FEATURES=true`. Treat core/proprietary/SaaS as a source-backed feature-partition question. Do not change flavor merely to obtain OCR/conversion functions: the external-tool families below are checked by core and disabled separately when their dependencies are absent.

## Portable mode

Portable mode is enabled by marker file `PDF_TUNNER_PORTABLE` beside the executable.

`frontend/editor/src-tauri/src/main.rs` detects the marker before Tauri starts and sets only PDF_Tunner-owned/bootstrap state. **Do not globally replace Windows `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before Tauri/WebView2 initializes.** CI proved that the first implementation reached portable directory creation but terminated before Tauri setup/backend logging when those host profile variables were replaced.

The portable boundary is component-specific:

- `PDF_TUNNER_PORTABLE_ROOT` -> executable directory;
- `utils::app_data_dir()` -> `<portable root>/data`, which localizes Stirling backend config, logs and working state;
- `utils::system_provisioning_dir()` -> `<portable root>/data/provisioning`;
- Tauri-side `add_log()` -> `<portable root>/data/logs/tauri-backend.log`, avoiding `%APPDATA%\Stirling-PDF\logs`;
- `tauri-plugin-log` 2.8.0 -> `<portable root>/data/tauri/logs/PDF_Tunner.log` via supported `TargetKind::Folder` only in portable mode; outside portable keep the default `LogDir` target;
- `tauri-plugin-store` 2.4.2 connection store -> `<portable root>/data/tauri/store/connection.json` only in portable mode; outside portable keep the relative `connection.json` path and normal Tauri `BaseDirectory::AppData` resolution;
- locally vendored `tauri-plugin-http` 2.5.8 cookie jar -> `<portable root>/data/tauri/http/.cookies` only in portable mode; outside portable the vendored source must still call official `app_cache_dir()`. Do not disable cookies to gain portability;
- `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=...` -> `<portable root>/data/tmp` for bundled Java only; do not replace native parent `TEMP/TMP` to achieve this;
- Stirling's default `system.tempFileManagement.baseTmpDir` therefore resolves to `<portable root>/data/tmp/stirling-pdf`, while `MobileScannerService` resolves to `<portable root>/data/tmp/stirling-mobile-scanner` through `java.io.tmpdir`;
- `WEBVIEW2_USER_DATA_FOLDER` -> `<portable root>/data/webview2`, containing WebView2 cookies, IndexedDB, Local Storage and browser cache without replacing global `LOCALAPPDATA`;
- `CALIBRE_CONFIG_DIRECTORY` -> `<portable root>/data/calibre`;
- packaged tool directories are prepended to `PATH` only when they exist;
- `TESSDATA_PREFIX` is set only when packaged Tesseract data exists;
- Windows/Linux deep-link protocol registration is skipped while portable mode is active so the app does not intentionally register `pdf-tunner://` in the host OS.

Run #15 proves the WebView2 override is active in the packaged production EXE: `data/webview2` contained 122 files (~4.6 MB) while the backend reached port 57658. **Do not use the parent `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` directory as a WebView2-only assertion.** The default WebView2 profile is the `EBWebView` child. The parent LocalAppData root must now additionally be checked for non-WebView Tauri persistence.

### Native Tauri profile containment

Run #50 (`32582638502`, commit `52fb5502e3c8c753357aba95415326dfe30ca7cf`) conclusively identified three real host-profile writes in artifact `9479633999`:

1. `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\.cookies` — `tauri-plugin-http` 2.5.8 cookie feature opens `.cookies` in Tauri `app_cache_dir()` during plugin setup.
2. `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\logs\PDF_Tunner.log` — `tauri-plugin-log` 2.8.0 defaults to `TargetKind::LogDir`.
3. `%APPDATA%\com.willsitogg.pdf-tunner\connection.json` — application code uses `app_handle.store("connection.json")`; `tauri-plugin-store` 2.4.2 resolves relative store paths through `BaseDirectory::AppData`.

Do not weaken the test and do not remove these files post-mortem. They must be created directly inside package `data/` while portable mode is active.

For log and store, use the plugins' supported APIs/path semantics as described above. `tauri-plugin-http` 2.5.8 exposes only `init()` and no cookie-store path override. Therefore the accepted downstream solution is a minimal local vendor of that exact plugin version, preserving its HTTP/cookie behavior and changing only the cookie-directory resolution when `PDF_TUNNER_PORTABLE_ROOT` exists. Keep the upstream source/version provenance obvious and do not grow this into an unrelated fork.

### Portable window-state

The official `tauri-plugin-window-state` dependency stays pinned and unchanged for non-portable Stirling. In portable mode do not register that plugin, because its save path is hard-wired through `app_config_dir()` and therefore host Roaming AppData.

Portable mode uses `utils::portable_window_state` instead. Its state file is:

`<portable root>/data/tauri/window-state/.window-state.json`

The implementation must preserve the upstream state semantics:

- `width` / `height`;
- `x` / `y`;
- `prev_x` / `prev_y` so maximization does not lose the prior normal position;
- `maximized`;
- `visible`;
- `decorated`;
- `fullscreen`;
- update normal size only when not maximized/minimized;
- capture the last window before it disappears;
- restore position only if the saved rectangle still intersects an available monitor;
- track dynamically-created Stirling windows through the centralized `commands/window.rs` builder;
- save before portable `cleanup_before_exit()` and immediate `process::exit()`, because relying on a later `RunEvent::Exit` is incompatible with the terminal portable shutdown sequence.

Do not call this layer proven merely because Rust compiles or the first packaged launch is green. `.github/scripts/validate-portable-window-state.ps1` must:

- delete both `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` and `%APPDATA%\com.willsitogg.pdf-tunner` before the first validation launch to establish a zero baseline;
- never delete either host root between or after validation launches;
- require `data/tauri/http/.cookies`, `data/tauri/logs/PDF_Tunner.log` and `data/tauri/store/connection.json` to be created package-locally;
- move/resize the real Win32 window and close normally;
- validate `data/tauri/window-state/.window-state.json` against measured geometry;
- launch the same assembled tree a second time and prove the saved geometry is restored;
- after each launch, hard-fail if either LocalAppData or Roaming AppData application root contains any file/subdirectory; a completely empty identifier directory may be recorded but is not persisted state;
- confirm normal parent/child cleanup.

Run #49 proved the first deliberate window-state launch and package-local JSON write but never reached the second launch. Run #50 proved why: the host roots contained actual Tauri state, not merely an empty directory. The next run must execute the second launch and all containment assertions before this layer is considered green.

Portable `ExitRequested` is terminal and synchronous: save portable window state, terminate the bundled backend, record final logs, call `AppHandle::cleanup_before_exit()`, then immediately call `std::process::exit()` with the requested code. Tauri explicitly documents that no Tauri API may be used after manual cleanup. Run #11 proved that relying on a later `RunEvent::Exit` can leave the Windows portable parent alive even after Java and other child processes are gone. Keep non-portable upstream behavior unchanged unless upstream itself changes.

Intended layout:

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

Never commit generated `data/` contents.

## Branding/config

Prefer additive downstream config over rewriting upstream config wholesale. Current overlay:

`frontend/editor/src-tauri/tauri.pdf-tunner.conf.json`

It supplies PDF_Tunner product/binary/window identity and prevents the downstream executable from following Stirling's upstream updater endpoint. Until PDF_Tunner has its own signed updater metadata, in-app updating is not considered an available feature.

## External dependency source of truth

Do not invent dependency lists. For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- the controller/service code of the feature being validated.

Direct runtime probes from `ExternalAppDepConfig`:

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

The upstream fat Docker base also confirms active installation/use of Calibre, Ghostscript, QPDF, ImageMagick, Poppler, `unpaper`, `pngquant`, LibreOffice, Tesseract languages + OSD, Python, WeasyPrint, `pdf2image`, OpenCV headless, OCRmyPDF, `unoserver`/Unoconvert infrastructure and conversion fonts.

For every Windows tool added later, document exact version, download/source, layout and validation here and in README.

## Windows toolchain strategy

Use `tools/` with one clear subdirectory per upstream tool. Do not dump unrelated DLLs into repository or portable root.

Expected PATH candidates currently include:

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

If a Windows executable name differs from what Stirling probes, provide a deterministic package-local shim/alias and test the exact Stirling probe name. CI must prove the assembled package resolves its own binaries; do not count software already installed on the runner.

## Build workflow

Permanent workflow path:

`.github/workflows/pdf-tunner-windows-portable.yml`

Normal final state should be manual `workflow_dispatch`. During the active bootstrap/fix loop, one temporary automatic `push` trigger is allowed and restricted to `pdf-tunner/windows-portable-v1`. The duplicate `pull_request` trigger was removed after it helped create a queue of obsolete duplicate runs and woke inherited upstream PR workflows. The heavy workflow must use `concurrency.group: pdf-tunner-windows-portable-${{ github.ref }}` plus `cancel-in-progress: true`. Keep PR #1 closed while active downstream CI does not need PR event coverage; reopen it as draft later when useful. Remove the development `push` trigger before merge to `main`.

Baseline sequence:

1. checkout this fork;
2. verify pinned upstream commit is an ancestor;
3. setup Node 22, Rust stable, Java 25 and Task;
4. run `task desktop:prepare` with Windows x64 JPDFium;
5. run `task desktop:test`;
6. build Tauri with `tauri.pdf-tunner.conf.json` and no installer;
7. assemble `PDF_Tunner.exe`, `libs/`, `runtime/jre/`, marker and empty `data/`;
8. launch the assembled executable;
9. find the actual backend port from package-local logs;
10. request `/api/v1/info/status`;
11. assert Stirling Java temp directories live under package `data/tmp` and were not newly created in host `%TEMP%`;
12. assert WebView2 populated package `data/webview2` and did not newly create `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView`;
13. request normal app shutdown and check for portable child-process leftovers;
14. run the real two-launch Win32 validator: establish clean Local+Roaming baselines, require the package-local HTTP/log/store files, prove package-local window-state save/restore and reject any host-profile content after either launch;
15. assert portable startup/shutdown did not newly register `HKCU\Software\Classes\pdf-tunner`;
16. on failure, write host/profile/registry/process evidence first, recursively inventory the PDF_Tunner/Stirling host application roots, summarize live WebView2 without recursively copying it, and copy safe package-local state including `data/tauri` best-effort;
17. upload diagnostics with hidden files enabled so `.window-state.json` and `.cookies` are retained when present;
18. clean generated runtime data from the distribution;
19. create ZIP + SHA-256;
20. upload only a short-lived CI artifact while the build remains bootstrap/non-release.

Startup diagnostics are implementation-branch evidence only. They must not become Release assets or permanent repository build output. A failure diagnostics step must itself be resilient: do not recursively copy a live `data/webview2` tree while Chromium/WebView2 can hold files open.

## Fixed WebView2 next layer

Do **not** integrate `pdf-tunner/webview2-fixed-runtime-v151` until the native Tauri profile containment + real second-launch window-state proof above is green on the current 2.14.3 base.

After that, integrate the isolated Fixed Runtime work cleanly over the new HEAD, preserve all recent README/AGENTS/workflow improvements, obtain and pin the real SHA-256 of Microsoft's official Fixed WebView2 Runtime and prove `msedgewebview2.exe` actually executes from the package-local runtime rather than the runner's Evergreen installation.

## Final validation target

Before a final Release, automate where technically possible:

- PDF_Tunner startup;
- backend startup and health endpoint;
- bundled JRE version;
- dependency path/version checks from the portable tree;
- Tesseract OCR + OSD/languages;
- OCRmyPDF end-to-end;
- LibreOffice -> PDF;
- PDF -> supported Office formats where Stirling exposes them;
- WeasyPrint;
- HTML/URL -> PDF;
- Calibre/EPUB;
- qpdf;
- Ghostscript;
- Poppler/pdftohtml;
- Python + OpenCV + NumPy where required;
- ImageMagick;
- `pngquant` and `unpaper` when exercised;
- RAR/CBR if a technically viable packaged Windows implementation is established;
- jbig2enc if integrated;
- representative end-to-end API tests across Stirling functional families;
- WebView2 runtime/profile containment;
- Tauri/plugin state containment and window-state restore;
- path containment under portable root;
- child-process cleanup;
- no accidental dependency on runner-installed tools;
- clean final ZIP;
- SHA-256.

Clearly distinguish CI validation from manual tests that must be performed by the user on real Windows 10/11 hardware.

## Upstream synchronization

For each future Stirling update:

1. inspect the new upstream version/commit;
2. compare PDF_Tunner delta against it;
3. update through a dedicated branch;
4. resolve only real conflicts;
5. re-audit desktop/external-tool behavior if relevant upstream files changed;
6. rerun the complete portable validation suite;
7. update README and AGENTS with the new base and decisions.

Do not recreate the application from scratch.

## Versioning/releases

- Keep the upstream Stirling version visible.
- Do not invent unnecessary versions.
- Add PDF_Tunner revision suffixes only for real downstream revisions.
- No final Release exists yet for this real-fork implementation.
- Before publication, verify ZIP SHA-256 and provenance.
- Only final published packages enter historical tracking.
- When one final revision replaces another: validate/publish new first, verify/archive prior exact package/hash as applicable, remove old Release listing, keep its git tag, then clean temporary workflows/scripts/outputs.

## Upstream coding conventions retained

Unless a PDF_Tunner rule above overrides them:

- use Task from repo root;
- run the relevant quality gate for changed code;
- Java is JDK 25 / Spring Boot 4.x / Jackson 3: inspect current imports/source instead of relying on older patterns;
- frontend is Vite + React + TypeScript and normal imports use `@app/*` so layer shadowing remains intact;
- file state flows through `FileContext`;
- preserve backend cleanup and single-instance behavior;
- consult root `DeveloperGuide.md`, `frontend/editor/DeveloperGuide.md`, `ADDING_TOOLS.md` and current source for implementation details.

## PDF_Tunner changelog

### 2026-08-21 — bootstrap v1 work

- Confirmed `WillsitoGG/PDF_Tunner` is a real fork and its initial `main` matched Stirling exactly at `7fb29d0`, version 2.14.3.
- Located `WillsitoGG/PDF_Tunner_Legacy` and audited its launcher/workflow as reference material.
- Chose Stirling's official Tauri desktop + JLink Java 25 architecture instead of the legacy C# wrapper.
- Audited the first source-backed external dependency inventory.
- Created branch `pdf-tunner/windows-portable-v1`.
- Added the initial pre-Tauri Windows portable environment redirection activated by `PDF_TUNNER_PORTABLE`.
- Added PDF_Tunner Tauri config/branding overlay.
- Added Windows portable build, backend-health, shutdown, ZIP and SHA-256 validation workflow.
- Diagnostic runs #5/#9 isolated pre-Tauri profile hijacking, then proved real packaged Tauri/Java/backend startup.
- Replaced global Windows-profile overrides with component-specific portable paths, skipped portable deep-link registration, and localized Tauri logs.

### 2026-08-22 — packaged startup containment

- Added Java-specific `java.io.tmpdir` redirection to package-local `data/tmp` without globally replacing native Windows `TEMP/TMP`.
- Run #11 proved Java temp and protocol-registry containment and isolated the remaining parent shutdown issue.
- Run #13 passed the complete portable bootstrap: production startup, backend health, Java-temp containment, protocol-registry containment, parent/child shutdown, package reset, ZIP and SHA-256.
- Added `WEBVIEW2_USER_DATA_FOLDER=data/webview2`; run #15 proved a real package-local WebView2 profile and normal backend startup.
- Audited and replaced `tauri-plugin-window-state` only in portable mode with package-local `data/tauri/window-state/.window-state.json`; run #19 proved no bootstrap regression.
- Integrated the real two-launch Win32 window-state proof.
- Run #49 proved the first deliberate launch and state-file write but stopped before the second launch on the then-insufficient Roaming-root classification.
- Removed the duplicate heavy `pull_request` trigger, retained one branch `push` plus `workflow_dispatch`, and kept serialized/cancelable CI.
- Staged the Fixed WebView2 151 work separately; do not integrate it before the current containment layer is green.

### 2026-08-23 — native Tauri AppData containment

- Run #50 artifact `9479633999` proved three actual host-profile leaks: LocalAppData `.cookies`, LocalAppData `logs/PDF_Tunner.log`, and Roaming AppData `connection.json`.
- Traced `.cookies` to `tauri-plugin-http` 2.5.8 `app_cache_dir()` setup, `PDF_Tunner.log` to `tauri-plugin-log` 2.8.0 default `LogDir`, and `connection.json` to `tauri-plugin-store` 2.4.2 relative-path resolution through `BaseDirectory::AppData`.
- Redirected logging with the plugin's supported `TargetKind::Folder` only in portable mode.
- Redirected the existing connection store path package-locally only in portable mode without changing any call-site semantics.
- Vendored the exact `tauri-plugin-http` 2.5.8 source locally because that version exposes no cookie-path configuration; changed only portable cookie-directory resolution and preserved normal `app_cache_dir()` behavior outside portable mode.
- Strengthened the two-launch validator to establish clean Local+Roaming baselines before launch, require all three package-local state files, reject any host content after either launch, still prove geometry restoration and still check child-process cleanup.
- This staging change remains unproven until a new Actions run completes the real second launch, host-containment checks and final ZIP generation.
