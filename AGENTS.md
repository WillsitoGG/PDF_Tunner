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
- `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=...` -> `<portable root>/data/tmp` for bundled Java only; do not replace native parent `TEMP/TMP` to achieve this;
- Stirling's default `system.tempFileManagement.baseTmpDir` therefore resolves to `<portable root>/data/tmp/stirling-pdf`, while `MobileScannerService` resolves to `<portable root>/data/tmp/stirling-mobile-scanner` through `java.io.tmpdir`;
- `WEBVIEW2_USER_DATA_FOLDER` -> `<portable root>/data/webview2`, containing WebView2 cookies, IndexedDB, Local Storage and browser cache without replacing global `LOCALAPPDATA`;
- `CALIBRE_CONFIG_DIRECTORY` -> `<portable root>/data/calibre`;
- packaged tool directories are prepended to `PATH` only when they exist;
- `TESSDATA_PREFIX` is set only when packaged Tesseract data exists;
- Windows/Linux deep-link protocol registration is skipped while portable mode is active so the app does not intentionally register `pdf-tunner://` in the host OS.

Run #15 proves the WebView2 profile override is active in the packaged production EXE: `data/webview2` contained 122 files (~4.6 MB) while the backend reached port 57658. **Do not use the parent `%LOCALAPPDATA%\com.willsitogg.pdf-tunner` directory as a WebView2 leak assertion.** The default WebView2 profile is the `EBWebView` child; test `%LOCALAPPDATA%\com.willsitogg.pdf-tunner\EBWebView` specifically and inventory the parent separately because native Tauri state may share the application identifier.

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

Do not call window-state proven merely because the Rust code compiles or the first packaged launch is green. The primary portable workflow invokes `.github/scripts/validate-portable-window-state.ps1` against the assembled production tree before generated runtime data is reset and the final ZIP is created. The validator deletes the host Roaming identifier directory to establish a zero baseline, moves/resizes the real Win32 window, closes normally, compares the package-local JSON with measured geometry, relaunches the same tree, verifies restored position/client size within tolerance and confirms no persisted content exists under `%APPDATA%\com.willsitogg.pdf-tunner`. A completely empty identifier directory is not treated as state; any file or subdirectory is a hard failure and is inventoried recursively.

Run #49 is the first real execution of this deliberate geometry proof. All preceding build/bootstrap checks passed. Its first validator launch closed normally and diagnostics prove `data/tauri/window-state/.window-state.json` was written. The validator then stopped before the second launch because the host Roaming identifier directory existed. The run-49 artifact did not include recursive host contents or the hidden JSON, so it does not prove that the directory contained state. The next diagnostic revision therefore includes the recursive host application tree and enables hidden-file artifact upload; do not weaken the rule beyond distinguishing an empty directory from actual persisted content.

`tauri-plugin-store` remains registered for upstream compatibility; repository search found no application call sites. Do not remove it speculatively. Any future relative store must be treated as an AppData-backed path unless explicitly localized.

Portable `ExitRequested` is terminal and synchronous: save portable window state, terminate the bundled backend, record final logs, call `AppHandle::cleanup_before_exit()`, then immediately call `std::process::exit()` with the requested code. Tauri explicitly documents that no Tauri API may be used after manual cleanup. Run #11 proved that relying on a later `RunEvent::Exit` can leave the Windows portable parent alive even after Java and other child processes are gone. Keep non-portable upstream behavior unchanged unless upstream itself changes.

Intended layout:

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  libs/
  runtime/
    jre/
    webview2/
      PROVENANCE.txt
      fixed/
        msedgewebview2.exe
        ...
  tools/
  data/
    webview2/
    tauri/
      window-state/
        .window-state.json
```

Never commit generated `data/` contents or the downloaded Fixed WebView2 runtime itself to git; CI/build assembly obtains the runtime from Microsoft and packages it into the portable ZIP.

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

Normal final state should be manual `workflow_dispatch`. During the active bootstrap/fix loop, one temporary automatic `push` trigger is allowed and restricted to `pdf-tunner/windows-portable-v1`. The duplicate `pull_request` trigger was removed after it helped create a queue of obsolete duplicate runs and woke inherited upstream PR workflows. The heavy workflow must use `concurrency.group: pdf-tunner-windows-portable-${{ github.ref }}` plus `cancel-in-progress: true`. Keep PR #1 closed while active downstream CI does not need PR event coverage; reopen it as draft later when useful. Remove the development `push` trigger before merge to `main`.

Baseline sequence before Fixed WebView2 promotion:

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
13. assert portable startup/shutdown did not persist files/subdirectories under `%APPDATA%\com.willsitogg.pdf-tunner`; record but do not misclassify a completely empty identifier directory;
14. inventory Local/Roaming application roots separately so Tauri/plugin state can be classified precisely;
15. assert portable startup/shutdown did not newly register `HKCU\Software\Classes\pdf-tunner`;
16. request normal app shutdown and check for portable child-process leftovers;
17. run the real two-launch Win32 window-state persistence/restore validator on the assembled production tree;
18. on failure, write host/profile/registry/process evidence first, recursively inventory the PDF_Tunner/Stirling host application roots, summarize live WebView2 without recursively copying it, and copy safe package-local state including `data/tauri` best-effort;
19. upload diagnostics with hidden files enabled so `.window-state.json` is retained when present;
20. clean generated runtime data from the distribution;
21. create ZIP + SHA-256;
22. upload only a short-lived CI artifact while the build remains bootstrap/non-release.

Startup diagnostics are implementation-branch evidence only. They must not become Release assets or permanent repository build output.

A failure diagnostics step must itself be resilient. In particular, do not recursively `Copy-Item` a live `data/webview2` tree: Chromium/WebView2 may hold files open and abort the diagnostic before host-state evidence is written. Record host state first, then summarize WebView2 by path/count/bytes/sample and copy only safe subtrees with best-effort error handling.

## Fixed WebView2 staged implementation

An isolated staging branch currently implements Microsoft Fixed WebView2 Runtime **151.0.4129.101 x64** on top of primary baseline commit `52fb5502e3c8c753357aba95415326dfe30ca7cf`. Do not call it proven or promote it to the primary branch until the immediately preceding window-state baseline is accepted.

Runtime contract:

- immutable runtime root: `<portable root>/runtime/webview2/fixed`;
- provenance file: `<portable root>/runtime/webview2/PROVENANCE.txt`;
- mutable browser profile remains `<portable root>/data/webview2`;
- `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` points at the fixed runtime root;
- `WEBVIEW2_USER_DATA_FOLDER` continues to point at the package-local profile;
- missing `msedgewebview2.exe` is a fatal portable bootstrap error; never silently fall back to host Evergreen;
- reject UNC paths and mapped remote drives via Win32 `GetDriveTypeW`, because Microsoft Fixed Version does not support network execution;
- recreate Microsoft's required Windows 10 Fixed Version 120+ AppContainer RX grants for `S-1-15-2-1` and `S-1-15-2-2` at each startup because ZIP extraction cannot be assumed to preserve NTFS ACLs;
- record bootstrap failures under package-local `data/logs/portable-bootstrap-error.log`.

Acquisition contract:

- `.github/scripts/prepare-webview2-fixed-runtime.ps1` receives exact version/architecture and optional expected SHA-256;
- `frontend/scripts/pdf-tunner-resolve-webview2-fixed.mjs` uses the existing pinned Puppeteer dev dependency to operate Microsoft's official WebView2 selector;
- accept only HTTPS download URLs whose hostname ends in `.microsoft.com`;
- compute the CAB SHA-256 before expansion;
- normalize the directory containing `msedgewebview2.exe` to `runtime/webview2/fixed`;
- verify `ProductVersion` begins with the requested exact version;
- write version, architecture, CAB SHA-256 and official selector source to `runtime/webview2/PROVENANCE.txt`;
- never commit downloaded Microsoft runtime binaries to git.

Validation contract:

- staged workflow variables define `PDF_TUNNER_WEBVIEW2_VERSION=151.0.4129.101` and a deliberately empty `PDF_TUNNER_WEBVIEW2_CAB_SHA256` for the first discovery execution only;
- the discovery execution must run the real application and all containment/window-state tests but must hard-fail before the validated ZIP is produced while the CAB SHA is empty;
- record `CAB_SHA256` from `PROVENANCE.txt`, pin it in the workflow, and rerun the full suite before accepting the layer;
- `.github/scripts/validate-webview2-fixed-runtime.ps1` checks ProductVersion/provenance before launch;
- live-process mode checks the post-start ACLs and requires at least one actual `msedgewebview2.exe` whose `ExecutablePath` is under the package-local fixed runtime root;
- diagnostics include WebView2 processes and Fixed Runtime provenance;
- final layout verification requires both `runtime/webview2/fixed/msedgewebview2.exe` and `runtime/webview2/PROVENANCE.txt`.

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
- Run #49 passed every pre-window-state build/bootstrap step and proved the first deliberate launch writes package-local `.window-state.json`; it then failed before the second launch solely because the validator treated existence of the Roaming identifier directory as state. The artifact did not preserve recursive host contents or the hidden JSON, so the next validator hard-fails on actual contents rather than an empty root and diagnostics now preserve both.
- Removed the duplicate heavy `pull_request` trigger during development, kept one branch-scoped `push` trigger plus `workflow_dispatch`, and added `concurrency` with `cancel-in-progress: true` so obsolete portable runs cannot accumulate again.
- Staged Microsoft Fixed WebView2 Runtime 151.0.4129.101 x64 on an isolated branch based on `52fb550...`: exact official-selector resolver, CAB SHA/provenance, local-drive enforcement, missing-runtime hard failure, Windows 10 AppContainer ACL recreation, live process-path proof and an explicit hash-discovery gate that prevents validated packaging until the CAB digest is pinned.
