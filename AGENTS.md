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
- `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=...` -> `<portable root>/data/tmp` for bundled Java only; do not replace native parent `TEMP/TMP` to achieve this;
- Stirling's default `system.tempFileManagement.baseTmpDir` therefore resolves to `<portable root>/data/tmp/stirling-pdf`, while `MobileScannerService` resolves to `<portable root>/data/tmp/stirling-mobile-scanner` through `java.io.tmpdir`;
- `WEBVIEW2_USER_DATA_FOLDER` -> `<portable root>/data/webview2`, containing WebView2 cookies, IndexedDB, Local Storage and browser cache without replacing global `LOCALAPPDATA`;
- `CALIBRE_CONFIG_DIRECTORY` -> `<portable root>/data/calibre`;
- packaged tool directories are prepended to `PATH` only when they exist;
- `TESSDATA_PREFIX` is set only when packaged Tesseract data exists;
- Windows/Linux deep-link protocol registration is skipped while portable mode is active so the app does not intentionally register `pdf-tunner://` in the host OS.

Run #15 proves the WebView2 override is active in the packaged production EXE: `data/webview2` contained 122 files (~4.6 MB) while the backend reached port 57658. **Do not use the parent `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` directory as a WebView2 leak assertion.** The default WebView2 profile is the `EBWebView` child; test `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView` specifically and inventory the parent separately because native Tauri state may share the application identifier.

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

The first integration commit is deliberately compile/start/save validation. Do not call window-state proven until CI confirms a package-local JSON and no new `%APPDATA%\com.willsitogg.pdf-tunner`. A subsequent validation increment must deliberately move/resize the packaged window, close it, launch the same portable tree again and confirm restoration within tolerance.

`tauri-plugin-store` remains registered for upstream compatibility; repository search found no application call sites. Do not remove it speculatively. Any future relative store must be treated as an AppData-backed path unless explicitly localized.

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

If a Windows executable name differs from what Stirling probes (e.g. Ghostscript commonly ships `gswin64c.exe` while Stirling checks `gs`), provide a deterministic package-local shim/alias and test the exact Stirling probe name.

CI must prove the assembled package resolves its own binaries. Do not count software already installed on the GitHub-hosted runner.

## Build workflow

Permanent workflow path:

`.github/workflows/pdf-tunner-windows-portable.yml`

Normal final state should be manual `workflow_dispatch`. During the active bootstrap/fix loop, **temporary automatic triggers** are allowed: `push` is restricted to `pdf-tunner/windows-portable-v1`, and `pull_request` targets `main` so the draft PR exposes workflow runs/logs through the connected GitHub tooling. Both automatic triggers are diagnostic/bootstrap infrastructure and must be removed before the change reaches `main`.

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
13. inventory Local/Roaming application roots separately so Tauri/plugin state can be classified precisely;
14. assert portable startup/shutdown did not newly register `HKCU\Software\Classes\pdf-tunner`;
15. on packaged-startup failure, write host/profile/registry/process evidence first, summarize live WebView2 without recursively copying it, and copy safe package-local state best-effort;
16. request normal app shutdown and check for portable child-process leftovers;
17. validate package-local Tauri window-state/no host Roaming state once the replacement is integrated;
18. clean runtime data from the distribution;
19. create ZIP + SHA-256;
20. upload only a short-lived CI artifact while the build remains bootstrap/non-release.

Startup diagnostics are implementation-branch evidence only. They must not become Release assets or permanent repository build output.

A failure diagnostics step must itself be resilient. In particular, do not recursively `Copy-Item` a live `data/webview2` tree: Chromium/WebView2 may hold files open and abort the diagnostic before host-state evidence is written. Record host state first, then summarize WebView2 by path/count/bytes/sample and copy only safe subtrees with best-effort error handling.

## Fixed WebView2 next layer

After portable window-state passes, bundle a Microsoft Fixed WebView2 Runtime. As of 2026-08-22 the current x64 catalog build verified during this work is `151.0.4129.101` (published 2026-08-20). Reverify before committing because this runtime is serviced frequently.

Use `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` for the package-local Fixed Runtime and keep `WEBVIEW2_USER_DATA_FOLDER` for the package-local profile. Microsoft documents that unpackaged Win32 apps using Fixed Version 120+ on Windows 10 need read/execute ACLs for SIDs `S-1-15-2-1` (`ALL APPLICATION PACKAGES`) and `S-1-15-2-2` (`ALL RESTRICTED APPLICATION PACKAGES`). Fixed Version cannot run from a network/UNC location. CI/manual validation must prove the bundled runtime is selected rather than a runner-installed Evergreen runtime.

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
- Temporarily enabled branch push/PR triggers for CI diagnostics; remove them before merge to `main`.
- Diagnostic runs #5/#9 isolated pre-Tauri profile hijacking, then proved real packaged Tauri/Java/backend startup.
- Replaced global Windows-profile overrides with component-specific portable paths, skipped portable deep-link registration, and localized Tauri logs.

### 2026-08-22 — packaged startup containment

- Added Java-specific `java.io.tmpdir` redirection to package-local `data/tmp` without globally replacing native Windows `TEMP/TMP`.
- Run #11 proved Java temp and protocol-registry containment and isolated the remaining parent shutdown issue.
- Run #13 passed the complete portable bootstrap: production startup, backend health, Java-temp containment, protocol-registry containment, parent/child shutdown, package reset, ZIP and SHA-256.
- General upstream CI on that baseline passed all required functional/build families except `dependency-review`, which fails because GitHub Dependency Graph is disabled on this fork.
- Added `WEBVIEW2_USER_DATA_FOLDER=data/webview2` instead of replacing `LOCALAPPDATA`.
- Run #15 proved the packaged WebView2 override creates a real local profile (122 files, about 4.6 MB) and does not prevent backend startup; backend port was 57658.
- Narrowed the hard host WebView2 assertion from the application LocalAppData root to the actual `EBWebView` child; kept broader Local/Roaming roots as diagnostics.
- Made startup diagnostics resilient to locked live Chromium files by recording host state first and summarizing—not copying—the live WebView2 profile.
- Audited and began replacing `tauri-plugin-window-state` only in portable mode. The replacement uses package-local `data/tauri/window-state/.window-state.json`, retains the official plugin in non-portable mode, tracks main/dynamic windows, preserves maximization metadata and monitor-safe restoration, and saves before terminal portable exit. Initial integration is under CI validation; second-launch geometry validation is still mandatory before calling it complete.
- Verified Microsoft Fixed WebView2 distribution requirements for the next layer: current x64 build 151.0.4129.101 at the time of audit, `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER`, Windows 10 AppContainer ACLs for Fixed Version 120+, and no UNC/network execution.
