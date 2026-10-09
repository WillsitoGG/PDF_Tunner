<p align="center">
  <img src="https://raw.githubusercontent.com/Stirling-Tools/Stirling-PDF/main/docs/stirling.png" width="80" alt="Stirling PDF logo">
</p>

<h1 align="center">Stirling PDF - The Open-Source PDF Platform</h1>

Stirling PDF is a powerful, open-source PDF editing platform. Run it as a personal desktop app, in the browser, or deploy it on your own servers with a private API. Edit, sign, redact, convert, and automate PDFs without sending documents to external services.

<p align="center">
  <a href="https://hub.docker.com/r/stirlingtools/stirling-pdf">
    <img src="https://img.shields.io/docker/pulls/frooodle/s-pdf" alt="Docker Pulls">
  </a>
  <a href="https://discord.gg/HYmhKj45pU">
    <img src="https://img.shields.io/discord/1068636748814483718?label=Discord" alt="Discord">
  </a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/Stirling-Tools/Stirling-PDF">
    <img src="https://api.scorecard.dev/projects/github.com/Stirling-Tools/Stirling-PDF/badge" alt="OpenSSF Scorecard">
  </a>
  <a href="https://github.com/Stirling-Tools/stirling-pdf">
    <img src="https://img.shields.io/github/stars/stirling-tools/stirling-pdf?style=social" alt="GitHub Repo stars">
  </a>
</p>

![Stirling PDF - Dashboard](images/home-light.png)

## Key Capabilities

- **Everywhere you work** - Desktop client, browser UI, and self-hosted server with a private API.
- **50+ PDF tools** - Edit, merge, split, sign, redact, convert, OCR, compress, and more.
- **Automation & workflows** - No-code pipelines direct in UI with APIs to process millions of PDFs.
- **Enterprise‑grade** - SSO, auditing, and flexible on‑prem deployments.
- **Developer platform** - REST APIs available for nearly all tools to integrate into your existing systems.
- **Global UI** - Interface available in 40+ languages.

For a full feature list, see the docs: **https://docs.stirlingpdf.com**

## Quick Start

```bash
docker run -p 8080:8080 docker.stirlingpdf.com/stirlingtools/stirling-pdf
```

Then open: http://localhost:8080

For full installation options (including desktop and Kubernetes), see our [Documentation Guide](https://docs.stirlingpdf.com/#documentation-guide).

## Resources

- [**Documentation**](https://docs.stirlingpdf.com)
- [**Homepage**](https://stirling.com)
- [**API Docs**](https://registry.scalar.com/@stirlingpdf/apis/stirling-pdf-processing-api/)
- [**Server Plan & Enterprise**](https://docs.stirlingpdf.com/Paid-Offerings)

## Support

- **Community**: [Discord](https://discord.gg/HYmhKj45pU)
- **Bug Reports**: [GitHub Issues](https://github.com/Stirling-Tools/Stirling-PDF/issues)

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

This project uses [Task](https://taskfile.dev/) as a unified command runner for all build, dev, and test commands. Run `task dev` to get started running the editor, run `task` to see the most common commands, or see the [Developer Guide](DeveloperGuide.md) for full details.

For adding translations, see the [Translation Guide](devGuide/HowToAddNewLanguage.md).

## License

Stirling PDF is open-core. See [LICENSE](LICENSE) for details.

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
