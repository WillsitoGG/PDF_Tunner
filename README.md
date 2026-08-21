# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) repository. This repository is a GitHub fork of Stirling PDF; PDF_Tunner is developed as a small downstream delta instead of rebuilding or wrapping Stirling from a separate codebase.

## Current base

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Initial upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Working branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64, portable ZIP**
- Current status: **portable bootstrap under development; no final PDF_Tunner release has been published yet**.

## Architecture decision

PDF_Tunner uses Stirling's own Tauri desktop application in `frontend/editor/src-tauri` as the desktop shell. The previous `PDF_Tunner_Legacy` C#/WebView2 launcher is retained only as a technical reference.

This is deliberately different from the previous approach:

1. the complete Stirling source tree remains the source of truth;
2. the official Tauri backend lifecycle, single-instance handling, file opening and shutdown logic are retained;
3. Stirling's official JDK 25/JLink desktop runtime is reused;
4. PDF_Tunner-specific changes are kept small and Windows-portable-specific;
5. external PDF/OCR/conversion tools are added to the portable package rather than expected from the host Windows installation.

## Portable mode

The Windows executable enables PDF_Tunner portable mode when a file named `PDF_TUNNER_PORTABLE` exists next to the executable. Before Tauri starts, the process redirects Windows profile/runtime variables such as `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` and `TMP` into the package-local `data/` tree.

This allows the Tauri plugins, the bundled Java backend and child processes to inherit portable locations instead of writing normal runtime state to the user's Windows profile. The portable launcher also prepends bundled tool directories to `PATH` when they exist.

The intended final layout is:

```text
PDF_Tunner/
  PDF_Tunner.exe
  PDF_TUNNER_PORTABLE
  libs/
  runtime/jre/
  tools/
  data/
```

`data/` is runtime state and is not committed to the repository.

## External dependency inventory

The list below comes from Stirling PDF 2.14.3 source code, primarily `ExternalAppDepConfig` and `RuntimePathConfig`, rather than from assumptions about older Stirling releases.

Stirling directly probes these external commands and disables the associated feature group when a required command is missing:

- Ghostscript: `gs`
- OCRmyPDF: `ocrmypdf`
- LibreOffice: `soffice`
- WeasyPrint: `weasyprint` (minimum checked version: 58)
- Poppler: `pdftohtml`
- Unoconvert: `unoconvert`
- qpdf: `qpdf` (minimum checked version: 12)
- Tesseract: `tesseract`
- RAR/CBR creation: `rar`
- Calibre: `ebook-convert`
- ImageMagick: `magick`
- Python: `python3` or `python`
- OpenCV: validated by importing `cv2` from Python

The upstream fat Docker toolchain additionally confirms active use of Calibre, Ghostscript, QPDF, ImageMagick, Poppler, `unpaper`, `pngquant`, LibreOffice, Tesseract/OSD, Python, WeasyPrint, `pdf2image`, OpenCV, OCRmyPDF and `unoserver`/Unoconvert infrastructure.

These tools will be integrated and validated incrementally in the Windows portable package. A tool is not considered supported merely because the application compiles.

## Build and validation

The permanent PDF_Tunner workflow is `.github/workflows/pdf-tunner-windows-portable.yml`. It is intentionally manual (`workflow_dispatch`) while the portable distribution is being stabilized.

The first validation layer checks:

- build from the real fork;
- official Tauri desktop tests;
- bundled JRE 25;
- production Tauri executable;
- package-local portable marker/data paths;
- real Java backend startup;
- detection of the dynamically assigned backend port;
- `/api/v1/info/status` health response;
- clean process shutdown;
- portable ZIP generation;
- SHA-256 generation.

The next layers will add real end-to-end tests for every external dependency family before a final Release is considered.

## Upstream synchronization

Keep the fork easy to compare with `Stirling-Tools/Stirling-PDF`:

- do not reorganize Stirling's root directories into generic `Archive/`, `Source/` or `Validation/` trees;
- keep PDF_Tunner-specific code localized;
- prefer additive Tauri config/workflow files over broad rewrites of upstream files;
- retain the exact upstream version/commit in documentation;
- before rebasing/updating, compare the PDF_Tunner delta against the new upstream and re-run the complete Windows portable validation suite.

## Repository rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same commit.** The two files are the permanent human/agent record of architecture, build, portability, validation, releases and tuning history.

---

## Upstream Stirling PDF README

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
