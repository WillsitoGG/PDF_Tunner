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
13. If connected GitHub tooling cannot enumerate `push` workflow runs natively, expose their IDs through a connector-readable Commit Status bridge inside the existing heavy workflow rather than adding another automatic workflow or asking the user for run URLs. The bridge must not commit/push repository content and must be removed with temporary development CI before final merge.

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
- `tauri-plugin-log` -> stdout plus `<portable root>/data/logs/tauri/` in portable mode, replacing its default Windows `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\logs` target while leaving non-portable behavior unchanged;
- `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=...` -> `<portable root>/data/tmp` for bundled Java only; do not replace native parent `TEMP/TMP` to achieve this;
- Stirling's default `system.tempFileManagement.baseTmpDir` therefore resolves to `<portable root>/data/tmp/stirling-pdf`, while `MobileScannerService` resolves to `<portable root>/data/tmp/stirling-mobile-scanner` through `java.io.tmpdir`;
- `WEBVIEW2_USER_DATA_FOLDER` -> `<portable root>/data/webview2`, containing WebView2 cookies, IndexedDB, Local Storage and browser cache without replacing global `LOCALAPPDATA`;
- desktop connection/user-info `tauri-plugin-store` -> `<portable root>/data/tauri/store/connection.json` in portable mode; keep the normal relative `connection.json` outside portable mode;
- auth token fallback `tauri-plugin-store` -> `<portable root>/data/tauri/store/tokens.json` in portable mode; keep the normal relative `tokens.json` outside portable mode and preserve Windows keyring-first behavior;
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
- `visible` defaults to true;
- `decorated` defaults to true;
- `fullscreen`;
- update normal size only when not maximized/minimized;
- capture the last window before it disappears;
- restore position only if the saved rectangle still intersects an available monitor;
- load the portable cache during plugin setup;
- in `on_window_ready`, restore and attach listeners directly to the native `tauri::Window<R>` supplied by Tauri, exactly as `tauri-plugin-window-state` 2.2.1 does; **do not try to immediately convert/re-resolve that object through `get_webview_window()` because the WebviewWindow may not yet be registered**;
- restore in upstream-compatible order: decorations, size, monitor-safe position, maximized, fullscreen, visibility/focus;
- use the same native `on_window_ready` hook for both config-created `main` and dynamically-created windows; do not also call `track_window()` manually after a dynamic builder because that installs duplicate listeners;
- save before portable `cleanup_before_exit()` and immediate `process::exit()`, because relying on a later `RunEvent::Exit` is incompatible with the terminal portable shutdown sequence.

Do not call window-state proven merely because the Rust code compiles or the first packaged launch is green. The primary portable workflow invokes `.github/scripts/validate-portable-window-state.ps1` against the assembled production tree before generated runtime data is reset and the final ZIP is created. The validator deletes the host Roaming identifier directory to establish a zero baseline, moves/resizes the real Win32 window, closes normally, compares the package-local JSON with measured geometry, relaunches the same tree, verifies restored position/client size within tolerance and confirms no persisted content exists under `%APPDATA%\com.willsitogg.pdf-tunner`. A completely empty identifier directory is not treated as state; any file or subdirectory is a hard failure and is inventoried recursively.

Run #49 was the first real execution of this deliberate geometry proof. All preceding build/bootstrap checks passed. Its first validator launch closed normally and diagnostics proved `data/tauri/window-state/.window-state.json` was written, but the then-current assertion stopped on the mere existence of the Roaming identifier directory before the second launch. That test-design issue is superseded by the content-aware assertion.

Run #50 (`run_id 32582638502`) reached the real second-launch check. The first launch measured and persisted client 824x581 at x=111/y=87. The second launch ended around 1028x749 at x=0/y=0. Neither the base nor PDF_Tunner Tauri config defines a minimum for `main`, so the test geometry is valid.

Run `32634578447` on commit `eb010bc84e09b57964053530614ff66828a9b3c7` passed every build/bootstrap step through the real packaged backend/containment smoke test, then failed the two-launch geometry validator. The failure artifact provided the actual root cause: **both launches logged `Portable window-state window-ready hook could not resolve WebviewWindow 'main'`**. The hook itself was firing, but PDF_Tunner discarded the valid native `Window` handed to it and attempted an early `get_webview_window()` lookup that returned `None`; therefore no restore or event listeners were attached. The package-local JSON still retained the first-launch 824x581 at x=111/y=87 state. Run `32825188381` proved the native-`Window<R>` correction on the assembled production EXE: the two-launch validator persisted the deliberate first-launch geometry package-locally and restored it on relaunch within tolerance.

### Other native Tauri state

Run `32598488359` proved the connection module's relative `connection.json` leaked to `%APPDATA%\com.willsitogg.pdf-tunner`; commit `eb010bc...` localized it to `data/tauri/store/connection.json`. Run `32634578447` then passed the real startup containment step, proving that connection-store localization and the `tauri-plugin-log` redirection at runtime.

The failure artifact from run `32634578447` exposed a second Roaming store: `%APPDATA%\com.willsitogg.pdf-tunner\tokens.json` (2 bytes), created by `commands/auth.rs` when the frontend clears/reads the Tauri Store auth fallback. The same module also had an independent relative `connection.json` used for user info. Portable mode must route both auth stores to `data/tauri/store/` while preserving keyring-first authentication and all non-portable relative paths. The implementation uses `AsRef<Path>` store-path objects, leaving every login/OAuth/token command call site and semantic unchanged. Run `32825188381` proved the package-local connection and token Store fallback files. Windows keyring/Credential Manager remains the first authentication path and is not claimed to be package-contained.

`tauri-plugin-log` 2.8.0 defaults to stdout plus Tauri `app_log_dir()`, which is `%LOCALAPPDATA%\<identifier>\logs` on Windows. Portable mode retains stdout and replaces only the file target with `data/logs/tauri/` via the official `TargetKind::Folder` API; run `32634578447` proved the packaged startup smoke succeeds with this configuration.

`tauri-plugin-http` 2.5.8 stays functionally enabled. PDF_Tunner vendors the verified official `http-v2.5.8` source and applies one localized portable-path adaptation: with `PDF_TUNNER_PORTABLE_ROOT`, its persistent cookie directory is `<portable root>/data/tauri/http`; without portable mode it still uses the official `app_cache_dir()`. Do not disable cookie/auth semantics. Run `32825188381` proved `data/tauri/http/.cookies` is created package-locally and the host Local/Roaming PDF_Tunner identifier roots contain no non-empty state.

### AppData containment closed

Run `32825188381` (job `97731512714`) on clean candidate `f088d0ad288a21d6419ff94b35c0f76b9667e7d5` is the acceptance proof for this phase. It passed official desktop preparation and Tauri/Cargo tests, production Tauri build, bundled JRE validation, real backend startup, the reinforced package-local Tauri-state/two-launch validator, runtime cleanup, ZIP/SHA generation and validated-artifact upload. Required portable locations are `data/tauri/http/.cookies`, `data/logs/tauri/PDF_Tunner.log`, `data/tauri/store/connection.json`, `data/tauri/store/tokens.json` and `data/tauri/window-state/.window-state.json`; host Local/Roaming identifier roots may exist only if empty. The protocol registry key and process tree must remain contained as enforced by the validator. Fixed WebView2 was subsequently closed by primary Run `33058462619`; the active portability phase is now the external Windows toolchain.

Portable `ExitRequested` is terminal and synchronous: save portable window state, terminate the bundled backend, record final logs, call `AppHandle::cleanup_before_exit()`, then immediately call `std::process::exit()` with the requested code. Tauri explicitly documents that no Tauri API may be used after manual cleanup. Run #11 proved that relying on a later `RunEvent::Exit` can leave the Windows portable parent alive even after Java and other child processes are gone. Keep non-portable upstream behavior unchanged unless upstream itself changes.

Intended layout:

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  libs/
  runtime/jre/
  runtime/webview2/
  tools/
    qpdf/
      bin/qpdf.exe
      PROVENANCE.txt
      SHA256SUMS.txt
      version.txt
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

`data/tauri/http/.cookies` is CI-proven by Run `32825188381`. Never commit generated `data/` contents.

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

### qpdf first external-tool candidate

- Version: `12.4.0`.
- Upstream release: `qpdf/qpdf` `v12.4.0`.
- Windows package: `qpdf-12.4.0-mingw64.zip`.
- Archive SHA-256: `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`.
- Portable rationale: qpdf documents that its MinGW64 Windows build does not require a Visual C++ runtime DLL, so PDF_Tunner prefers it over MSVC64 to avoid a host prerequisite even though MSVC can be slightly faster.
- Portable layout: `tools/qpdf/`, with executable `tools/qpdf/bin/qpdf.exe`.
- Stirling requirement: its source checks command `qpdf` and enforces minimum `12.0.0`.
- `.github/scripts/prepare-qpdf.ps1` owns download, pinned archive-hash verification, extraction/normalization and fixed provenance files. The downloaded archive must never enter the product tree.
- `.github/scripts/validate-qpdf.ps1` must verify packaged executable hash/provenance/version, resolve `qpdf` from an isolated package-first PATH, generate an independent deterministic one-page PDF with byte-accurate xref offsets, require qpdf `--check` plus exact `--show-npages` result `1`, and—during the real PDF_Tunner launch—find Stirling's own `qpdf 12.4.0 meets minimum 12.0.0` dependency evidence in package-local logs.
- `SamplePdf` is legacy/optional only: if supplied it may provide an additional qpdf read check only when its byte signature begins `%PDF-`; it can never replace or bypass the generated mandatory PDF gate.
- Do not mark qpdf supported merely because these scripts exist; acceptance requires a complete green primary Windows portable run on the assembled tree.

## Build workflow

Permanent workflow path:

`.github/workflows/pdf-tunner-windows-portable.yml`

Normal final state should be manual `workflow_dispatch`. During the active bootstrap/fix loop, one temporary automatic `push` trigger is allowed and restricted to `pdf-tunner/windows-portable-v1`. The duplicate `pull_request` trigger was removed after it helped create a queue of obsolete duplicate runs and woke inherited upstream PR workflows. The heavy workflow must use `concurrency.group: pdf-tunner-windows-portable-${{ github.ref }}` plus `cancel-in-progress: true`. Keep PR #1 closed while active downstream CI does not need PR event coverage; reopen it as draft later when useful. Remove the development `push` trigger before merge to `main`.

Connector run discovery bridge during active development:

- implementation: `.github/scripts/publish-push-run-statuses.ps1`, invoked as the first post-checkout step of the existing Windows portable job;
- permissions: `actions: read`, `contents: read`, `statuses: write`;
- current run: publishes `GITHUB_RUN_ID`, `GITHUB_RUN_NUMBER`, `GITHUB_SHA` and the exact Actions URL immediately as Commit Status context `pdf-tunner/windows-portable-push`;
- backfill: queries recent runs of `.github/workflows/pdf-tunner-windows-portable.yml` through GitHub Actions REST filtered to `event=push` and `pdf-tunner/windows-portable-v1`, then publishes the same status context on each historical head SHA;
- state mapping: active runs -> `pending`; successful completed runs -> `success`; failure/timeout/action-required -> `failure`; other terminal conclusions -> `error`;
- each status description includes the run number/result and `run_id`; `target_url` is the exact Actions run URL;
- connected tooling calls `get_commit_combined_status`, extracts the run ID/target URL, then uses normal run/job/log/artifact endpoints;
- no second workflow or job is created, no repository content is written during execution, and no CI recursion is possible;
- remove this development-only status bridge with other temporary CI before final merge to `main`.

Baseline sequence:

1. checkout this fork;
2. publish/backfill connector-readable `push` run IDs as Commit Status metadata;
3. verify pinned upstream commit is an ancestor;
4. setup Node 22, Rust stable, Java 25 and Task;
5. run `task desktop:prepare` with Windows x64 JPDFium;
6. run `task desktop:test`;
7. build Tauri with `tauri.pdf-tunner.conf.json` and no installer;
8. assemble `PDF_Tunner.exe`, `libs/`, `runtime/jre/`, marker and empty `data/`;
9. stage and validate pinned Fixed WebView2 into `runtime/webview2/`;
10. stage official qpdf into `tools/qpdf/`, verify archive SHA/provenance/executable hash/version, then prove it from an isolated package-first PATH and the mandatory generated valid PDF input;
11. launch the assembled executable;
12. find the actual backend port from package-local logs and request `/api/v1/info/status`;
13. prove Stirling's own runtime dependency check accepted package-first qpdf 12.4.0 against its 12.0.0 minimum;
14. assert Stirling Java temp directories live under package `data/tmp` and were not newly created in host `%TEMP%`;
15. assert WebView2 populated package `data/webview2` and did not newly create `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView`;
16. assert portable startup/shutdown did not persist files/subdirectories under `%APPDATA%\com.willsitogg.pdf-tunner`, including connection/user-info/token-store state;
17. assert native Tauri log output and HTTP cookie state are package-local and inventory Local/Roaming application roots separately;
18. assert portable startup/shutdown did not newly register `HKCU\Software\Classes\pdf-tunner`;
19. request normal app shutdown and check for portable child-process leftovers;
20. run the real two-launch Win32 window-state persistence/restore validator on the assembled production tree;
21. on failure, write host/profile/registry/process evidence first, recursively inventory the PDF_Tunner/Stirling host application roots, summarize live WebView2 without recursively copying it, and copy safe package-local state including `data/tauri` best-effort;
22. upload diagnostics with hidden files enabled so `.window-state.json` is retained when present;
23. clean generated runtime data from the distribution and revalidate qpdf in the final tree;
24. create ZIP + SHA-256;
25. upload only a short-lived CI artifact while the build remains bootstrap/non-release.

Startup diagnostics are implementation-branch evidence only. They must not become Release assets or permanent repository build output.

A failure diagnostics step must itself be resilient. In particular, do not recursively `Copy-Item` a live `data/webview2` tree: Chromium/WebView2 may hold files open and abort the diagnostic before host-state evidence is written. Record host state first, then summarize WebView2 by path/count/bytes/sample and copy only safe subtrees with best-effort error handling.

## Fixed WebView2 accepted

Primary Run `33058462619` (#62), job `98471041328`, on commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4` is the permanent-workflow proof for bundled Microsoft Fixed WebView2 `151.0.4129.101` x64. It passed official Stirling desktop preparation, Tauri/Cargo tests, production assembly, pinned runtime staging/static/live selection, bundled Java 25, backend HTTP 200, package-local browser profile, AppContainer ACLs, AppData/TEMP/registry/process containment, two-launch window-state restoration, final CAB SHA/no-CAB checks, package cleanup, ZIP/SHA and artifact upload. No Evergreen/system WebView2 fallback is accepted.

Keep `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` pointed at package-local `runtime/webview2/fixed`, keep `WEBVIEW2_USER_DATA_FOLDER` package-local, retain the Windows 10 Fixed Version 120+ AppContainer SID grants, and continue rejecting UNC/network execution. The next active portability phase is the external toolchain, not additional WebView2 bootstrap work.

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
- Audited and replaced `tauri-plugin-window-state` only in portable mode. The replacement uses package-local `data/tauri/window-state/.window-state.json`, retains the official plugin in non-portable mode, tracks main/dynamic windows, preserves maximization metadata and monitor-safe restoration, and saves before terminal portable exit.
- Run #19 passed the full portable bootstrap with the custom portable window-state layer integrated, proving no startup/shutdown regression.
- Integrated a real two-launch window-state proof directly into the primary Windows portable workflow: it moves/resizes the assembled production Win32 window, verifies package-local JSON, relaunches for restoration, rejects Roaming AppData content and checks child-process cleanup before the final ZIP is built.
- Run #49 passed every pre-window-state build/bootstrap step and proved the first deliberate launch writes package-local `.window-state.json`; its initial Roaming-root assertion was then corrected to distinguish an empty identifier directory from actual persisted state.
- Removed the duplicate heavy `pull_request` trigger during development, kept one branch-scoped `push` trigger plus `workflow_dispatch`, and added `concurrency` with `cancel-in-progress: true` so obsolete portable runs cannot accumulate again.
- Replaced the failed separate run-index workflow experiment with an integrated Commit Status bridge: the primary Portable run now publishes its own `run_id` and backfills recent `push` run IDs onto their head commits, making them discoverable through the existing connector without adding another workflow/job.
- Verified Microsoft Fixed WebView2 distribution requirements for the next layer: current x64 build 151.0.4129.101 at the time of audit, `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER`, Windows 10 AppContainer ACLs for Fixed Version 120+, and no UNC/network execution.

### 2026-08-23 — real window restore and native Tauri state audit

- Recovered `push` runs autonomously through the Commit Status bridge; run #50 is `32582638502`, later primary runs include `32598488359` and `32634578447`.
- Run #50 proved actual package-local window-state write with measured client 824x581 at x=111/y=87, then proved second-launch restoration still failed around 1028x749 at x=0/y=0.
- Confirmed the main production Tauri config has no `minWidth`/`minHeight`; the smaller test geometry is valid and must not be weakened to hide the restore defect.
- Run `32598488359` diagnostics proved the Java backend started successfully on port 53150 and shut down cleanly; the startup step failed instead on real Roaming `%APPDATA%\com.willsitogg.pdf-tunner\connection.json` state.
- Localized the desktop connection `tauri-plugin-store` to `data/tauri/store/connection.json` in portable mode while preserving normal non-portable behavior.
- Classified `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\logs\PDF_Tunner.log` as the default `tauri-plugin-log` file target and redirected that target to `data/logs/tauri/` while retaining stdout.
- Run `32634578447` passed all build/bootstrap checks through the real backend/containment smoke test, proving the connection-store and log redirections; the window validator still failed.
- Its diagnostics identified the actual window-state defect: `on_window_ready` correctly supplied a native `Window`, but PDF_Tunner immediately tried `get_webview_window("main")`, which returned `None` at that lifecycle point. The candidate now restores/listens directly on the native `Window<R>` and mirrors upstream restore ordering/defaults.
- The same diagnostics exposed `%APPDATA%\com.willsitogg.pdf-tunner\tokens.json` from the authentication Tauri Store fallback and a second relative `connection.json` path in auth user-info code. Both are localized to `data/tauri/store/` in portable mode without changing keyring/login/OAuth semantics; CI proof is pending.
- Classified `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\.cookies` as `tauri-plugin-http` 2.5.8's persistent cookie jar. Verified official ref `tauri-apps/plugins-workspace` `http-v2.5.8` and confirmed current `v2` still hard-wires `app_cache_dir()/.cookies`; cookies/auth must be preserved, so this leak remains explicitly pending a minimal source-compatible localization rather than disabling the feature.

### Permanent Fixed WebView2 acceptance

- Staging Run `32977842546` is the green acceptance evidence for Fixed WebView2 `151.0.4129.101` x64. Permanent Windows builds must retain the exact official Microsoft CDN CAB URL and SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`.
- A passing build must prove static runtime integrity and live selection of package-local `runtime\webview2\fixed\msedgewebview2.exe`, package-local `data\webview2`, both AppContainer SID ACLs with Allow + ReadAndExecute + ObjectInherit + ContainerInherit, backend HTTP 200, two-launch/AppData/window-state containment, no orphan package-local child processes, and no CAB archive in the final portable root.
- Do not promote `.github/workflows/pdf-tunner-webview2-fixed-stage.yml` or diagnostic artifacts into the permanent product workflow/release. The primary `.github/workflows/pdf-tunner-windows-portable.yml` owns the accepted gates.
- Upstream base identity is the exact snapshot commit `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`, which reports version `2.14.3` in its source metadata. Do not describe that SHA as identical to the separate upstream `v2.14.3` tag object.

### 2026-08-27 — primary Fixed WebView2 gate false-negative correction

- Primary Run `32982806130` / job `98339314033` on commit `ac0833d4c9aee3276918934048d5c74e55c61e21` passed steps 1–15 and failed step 16 only after the real packaged application was already running. Its failure artifact proves backend HTTP 200, bundled Java 25, Fixed WebView2 `151.0.4129.101` processes from `runtime\webview2\fixed`, package-local `data\webview2\EBWebView`, package-local Java temp, no host `EBWebView`, no Stirling Roaming AppData, no host TEMP leak and no `pdf-tunner` protocol key.
- The step-16 wrapper incorrectly tested `$LASTEXITCODE` after calling `.github/scripts/validate-webview2-fixed-runtime.ps1`. `$LASTEXITCODE` belongs to the most recently invoked native executable and is not a reliable result code for a PowerShell script; null/stale state can therefore fail a successful validator. Never use `$LASTEXITCODE` to infer `.ps1` success. Let terminating errors propagate, or use PowerShell-native status handling where genuinely needed.
- The permanent workflow now emits its live-WebView2 success line only after the validator returns without a terminating error.

### 2026-08-27 — primary Fixed WebView2 accepted; qpdf toolchain begins

- Primary Run `33058462619` (#62), job `98471041328`, on commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4` passed every permanent portable gate, resolving the prior false negative. Fixed WebView2 `151.0.4129.101` is now accepted in the primary workflow; the resulting CI artifact was `9641278175`.
- Closed the Fixed WebView2 phase and moved the active implementation layer to external Windows dependencies.
- Selected upstream qpdf `12.4.0` `mingw64` as the first candidate because Stirling's exact source probes `qpdf` and requires at least `12.0.0`; MinGW64 avoids a host Visual C++ runtime DLL dependency, which is preferable for PDF_Tunner's portable target.
- Pinned official `qpdf-12.4.0-mingw64.zip` SHA-256 `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5` and added reproducible staging into `tools/qpdf/` without committing/downstreaming the ZIP itself.
- Added isolated package-first PATH/version/hash/provenance/sample-PDF validation plus Stirling-backend dependency-log proof. This qpdf integration remains a candidate until the resulting complete primary run is green.
- Run `33066989038` (#64) passed qpdf archive staging and reached the mandatory functional read gate, where it failed because `test_globalsign.pdf` is actually a GlobalSign HTML 404 page (`<!DOCTYPE html>`), not PDF data. The validator now generates an independent minimal valid one-page PDF with calculated xref offsets, requires packaged qpdf `--check` and exact page count `1`, and keeps all package-first/path/hash/version/backend gates intact. qpdf remains pending until the corrected full run is green.

### 2026-08-27 — qpdf Run #65 PowerShell parser correction

- Run `33071025776` (#65), job `98512996138`, passed qpdf 12.4.0 MinGW64 download, pinned archive SHA-256 verification and staging into `tools/qpdf/`, then failed when PowerShell parsed `.github/scripts/validate-qpdf.ps1` before any qpdf command executed.
- Exact cause: the error-message interpolation `"... $LASTEXITCODE: ..."` is invalid because PowerShell treats the colon as part of the variable reference unless the variable name is braced. The validator now uses `${LASTEXITCODE}:`.
- The rest of the qpdf validator was audited for the same interpolation pattern. No qpdf gate is relaxed: package-first PATH resolution, executable/archive hashes, provenance/version, generated-PDF `--check` and exact page count, Stirling backend minimum-version proof and final-tree validation remain mandatory.
- qpdf is still a candidate pending a complete green primary Windows portable run.
