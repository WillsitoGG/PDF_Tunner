# PDF_Tunner v3.1.0 migration status

## PDF_Tunner v3.1.0 — Portable migration A1 (NOT BUILT)

**Exact upstream source:** Stirling-PDF v3.1.0 tag `b99fa929e365760c863956bf23c127b098c288e5`. This integration branch descends directly from the upstream commit, not a guessed version bump. Its sibling branch `pdf-tunner/upstream-v3.1.0-base` preserves the unmodified official tree.

**Previous working reference:** `pdf-tunner/windows-portable-v1`, last passing Windows CI Run #134, build source `1a61b6412414dc3b6b1d2ae007b5cef5477c08fa`. Do not alter this validated branch or main while v3 migration is incomplete.

**Migrated now (source-side only):** Windows 10/11 portable marker bootstrap, package-first pinned dependency path setup, fixed WebView2 bootstrap, portable app-data/provisioning path mapping, branded Tauri overlay, native `is_pdf_tunner_portable` flag for frontend, disable system deep-link registration in portable, and adapt Java loopback/temp/HotSpot flags to the new v3.1 backend while preserving its new shutdown-file handling. Upstream Rust Cargo feature set is preserved with one additional Windows file-storage feature used by the imported bootstrap.

**Not migrated / not validated:** portable window-state/log plugin storage, frontend account/mobile/branding policy, converter packaging scripts and CI workflow, new v3.1 Java/React test compatibility, UI/ProcMon tests, full Windows ZIP. The current branch MUST NOT be distributed as PDF_Tunner.

**Next gates:** port native window-state and log isolation against v3.1 lifecycle, then adapt package pipeline and frontend/backend local-only constraints. Run cheap native/frontend/Java checks before one expensive Windows packaged CI. Keep all non-Enterprise PDF features except explicitly requested mobile upload, login/cloud/account and admin navigation. Keep legal attribution intact. Document every code change in README and AGENTS and do not publish a Release or edit main.

### v3.1.0 migration slice A2 — isolate native window state/logs (unverified code)

Port the previously accepted package-local window-state cache into the upstream v3.1 Tauri plugin lifecycle. For marked portable runs write geometry under `data/tauri/window-state` and Tauri logs under `data/logs/tauri`, not the host profile. Preserve the upstream new main-window creation, watcher shutdown, Java shutdown-file path and default native plugin outside portable mode. On CloseRequested capture window geometry before destruction; on ExitRequested persist it before backend cleanup and native exit. Source-only integration commit; no Rust compilation, GUI or Windows 10 VM validation yet. Remaining: adapt full converter/packaging CI, local-only frontend/backend policy and approved branding.

### Cheap v3.1.0 migration validation (source-level; workflow branch only)

Added an isolated branch-specific lightweight workflow `pdf-tunner-v3-migration-preflight.yml` and executable Python checks `validate-v3-migration.py`. It parses all changed Rust portable sources with rustfmt, verifies pinned upstream 3.1.0 Tauri base metadata, portable overlay identity, native mode detection, local Java shutdown/TEMP/loopback, WebView2 location and window-state/log isolation wiring. It does not download or build LibreOffice/Java/OCR, perform native linking or GUI tests, or retain large binaries. This temporary migration workflow is scoped exclusively to the v3 integration branch (concurrency cancels obsolete runs) and must be reviewed/removed on final cleanup. A green source preflight is only a preparatory milestone; the product is not buildable/accepted until later gates pass.

### v3.1.0 migration slice A3 — stage verified former portable toolchain scripts (NOT YET RETESTED)

Added the previously validated v2.14.3 Windows portable dependency preparation/verification scripts as byte-identical source Git blobs, without rewriting download URLs, security pins or provenance. This includes qpdf, Poppler, LibreOffice, Calibre, ImageMagick, Ghostscript, Tesseract, OCRmyPDF/Python, conversion fonts, WeasyPrint, WebView2 and auxiliary image/OCR/ebook/CBR toolchains. Retained the four purpose-built launchers in scripts. These are now migration INPUTS, not an approved v3.1 package. The full Windows CI workflow was intentionally not imported because it pins old upstream 2.14.3 and old Java/frontend output paths; it must be reconciled to v3.1 before being enabled. No 1.9GB portable build or new Release. Do not treat old converter tests as v3 runtime acceptance until verified against v3.1 endpoints/dependency usage.

**Next:** reconcile actual upstream v3.1 backend Jar build and frontend packaging; adapt the strict Windows CI with identical SHA pins and all original functional gates; then update the branding scripts for the user-supplied blue mark. Run targeted tests first. No changes to the stable old branch or main.

### v3.1.0 migration slice A4 — restore pinned Windows acceptance inputs (source-only)

Nine missing v2.14.3 support inputs are staged from the last passing `pdf-tunner/windows-portable-v1` tree as the original Git blobs: two Python dependency locks (`ocrmypdf-py312-windows-x64.lock.txt`, `opencv-py312-windows-x64.lock.txt`) and the Windows host-boundary audit, startup diagnostics, previous branding preparation/validation, CI-status helper, RAR probe and window-state verification. These files complement A3 and are **migration inputs only, not validated v3.1.0 runtime tools**. The former Windows workflow is deliberately not active or imported wholesale: it pins Stirling 2.14.3 and must be reconciled to the v3.1.0 build and frontend layout. The previous branding script is only a reference until the approved blue identity is applied.

The lightweight source gate checks the staged inputs plus the official v3.1.0/JDK 25 desktop JLink/JAR task contracts; it does not download external runtimes or claim executable functionality. Keep `main` and the v2 branch untouched, do not launch a large build prematurely, and publish no Release without authorization.

**Next:** port the full Windows CI/packaging workflow to v3.1.0, retaining exact dependency SHA pins and the backend, OCR, LibreOffice, frontend, lifecycle, GUI, host-boundary, ZIP and SHA-256 gates; run cheap compatibility checks before one controlled Windows build.

### v3.1.0 migration slice A5 — block official auto-update in marked portable Windows mode (source-only)

Adapted three existing v3.1 React/TypeScript files (without replacing the upstream components): the desktop startup update popup, the shared upstream release/update service, and desktop Preferences. They now call the existing native `is_pdf_tunner_portable` command and, for package-marked portable runs, avoid fetching Stirling updater metadata, displaying update controls, and probing the Tauri updater. Detection failure is handled conservatively (no external update), while non-portable upstream behavior is preserved. The branch preflight now checks these contracts for regressions. This is source integration **only**, not a TypeScript build, live network test, or acceptance of the frontend branding/account UI.

**Next:** independently verify the new frontend component tree (onboarding/sign-in/cloud/wallet and branding) against the approved local-only policy, then reconcile full Windows v3.1 CI and packaging with pinned dependencies. Do not publish or change `main`.
