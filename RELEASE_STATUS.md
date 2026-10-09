# PDF_Tunner v3.1.0 migration status

## PDF_Tunner v3.1.0 — Portable migration A1 (NOT BUILT)

**Exact upstream source:** Stirling-PDF v3.1.0 tag `b99fa929e365760c863956bf23c127b098c288e5`. This integration branch descends directly from the upstream commit, not a guessed version bump. Its sibling branch `pdf-tunner/upstream-v3.1.0-base` preserves the unmodified official tree.

**Previous working reference:** `pdf-tunner/windows-portable-v1`, last passing Windows CI Run #134, build source `1a61b6412414dc3b6b1d2ae007b5cef5477c08fa`. Do not alter this validated branch or main while v3 migration is incomplete.

**Migrated now (source-side only):** Windows 10/11 portable marker bootstrap, package-first pinned dependency path setup, fixed WebView2 bootstrap, portable app-data/provisioning path mapping, branded Tauri overlay, native `is_pdf_tunner_portable` flag for frontend, disable system deep-link registration in portable, and adapt Java loopback/temp/HotSpot flags to the new v3.1 backend while preserving its new shutdown-file handling. Upstream Rust Cargo feature set is preserved with one additional Windows file-storage feature used by the imported bootstrap.

**Not migrated / not validated:** portable window-state/log plugin storage, frontend account/mobile/branding policy, converter packaging scripts and CI workflow, new v3.1 Java/React test compatibility, UI/ProcMon tests, full Windows ZIP. The current branch MUST NOT be distributed as PDF_Tunner.

**Next gates:** port native window-state and log isolation against v3.1 lifecycle, then adapt package pipeline and frontend/backend local-only constraints. Run cheap native/frontend/Java checks before one expensive Windows packaged CI. Keep all non-Enterprise PDF features except explicitly requested mobile upload, login/cloud/account and admin navigation. Keep legal attribution intact. Document every code change in README and AGENTS and do not publish a Release or edit main.
