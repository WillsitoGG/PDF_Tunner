# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- No final PDF_Tunner v1 Release exists yet; `main` remains the clean upstream base during portable development.
- Latest complete green primary regression: **Run #95** (`33695530172`), job `100463449110`, functional commit `a7a118e852277069c8ab13cc2f25121f9be87fea`.
- Active external-toolchain candidate: **Calibre `9.14.0` / `ebook-convert`**. Focused candidate Run #1 (`33743422083`), job `100610347852`, commit `e329e3c128ab9d26437f5dffad8a47e80b0c6362`, passed; Calibre is still not accepted until the complete primary workflow is green with all previous gates enabled.

## Accepted portable layers

The complete primary Windows workflow has accepted:

- native Tauri/JRE portable bootstrap, package-local backend state, Java temp, WebView2 profile, Tauri stores/logs/cookies/window state and shutdown containment;
- Fixed WebView2 `151.0.4129.101` x64;
- qpdf `12.4.0` MinGW64;
- ImageMagick `7.1.2-30` portable Q16 x64;
- Ghostscript `10.07.1` Win64;
- Tesseract OCR release `5.5.3`, Windows CLI `5.5.3.20260724`, with pinned `eng`, `spa` and `osd` models;
- Python `3.12.14` x64 portable runtime with authenticated dependency lock;
- OCRmyPDF `17.10.0` with package-relative native launcher;
- NumPy `2.5.2`;
- OpenCV via authenticated `opencv-python-headless 4.14.0.94` (runtime/core `4.14.0`) and real Stirling `split_photos.py` E2E;
- LibreOffice `26.2.5` with package-relative native `unoconvert.exe`;
- Poppler `26.02.0` Windows x64 with package-local `pdftohtml`, `pdfinfo` and `pdfimages`;
- **WeasyPrint `69.0`**, official Kozea Windows release, package-relative shim and real Stirling HTML→PDF + Markdown→PDF backend proof.

## Acceptance evidence by recent block

### Python + OCRmyPDF — accepted

PDF_Tunner packages Python `3.12.14` x64 from `astral-sh/python-build-standalone` release `20260825`, archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`, and OCRmyPDF `17.10.0`, wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`. The native relative launcher resolves sibling `python.exe`, executes `python.exe -m ocrmypdf`, localizes OCRmyPDF temp to `data/tmp/ocrmypdf/` and Python cache to `data/python-cache/`.

Primary Run #77 (`33201568275`), job `98952028665`, commit `54802c15427673c0e95738195947ab76239d6e31`, passed isolated package-only resolution, real searchable-PDF OCR, text extraction, package-local temp/cache, relocation with spaces and live backend acceptance.

### Authenticated Python dependency lock + NumPy — accepted

The accepted lock contains 28 exact packages and authenticates the selected Windows x64/universal wheel for each package. Current lock SHA-256: `ededb999049d81b85527f4d4aa679179e747669df300083d91bc2dd4e14e430f`. NumPy `2.5.2` uses CPython 3.12 Windows AMD64 wheel SHA-256 `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`.

Complete primary Run #90 (`33530454097`), job `99931980241`, commit `c32fb84eb2c0f7b157ef3217c59e57eee20b895b`, passed every earlier gate plus exact inventory, package-local NumPy compiled-core/DLL AMD64 validation, deterministic matrix multiplication and relocation with spaces. NumPy is formally accepted.

### OpenCV 4.14.0.94 — accepted

Pinned Stirling `split_photos.py` imports `cv2` + NumPy. PDF_Tunner uses authenticated `opencv-python-headless 4.14.0.94`, wheel SHA-256 `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`, in dedicated lock `.github/config/opencv-py312-windows-x64.lock.txt` with lock SHA-256 `ec341586a884015445d4e28debbdd00b57ac903a36405bc7e0b9020e12dfd6c6`.

Complete primary Run #92 (`33557169326`), job `100020722841`, commit `c4c2b7f6e320840faf3d8c61967351b529875a50`, passed every prior gate plus distribution/runtime identity, package-local AMD64 native validation, real Stirling `split_photos.py` E2E yielding exactly two valid crops, relocation with spaces, OCR/NumPy regressions, live backend acceptance and final ZIP/layout validation. OpenCV is formally accepted.

### LibreOffice 26.2.5 + native `unoconvert` — accepted

PDF_Tunner administratively extracts the official LibreOffice Windows x86-64 MSI rather than installing it on the runner. MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`. Native `tools/bin/unoconvert.exe` translates Stirling's CLI to bundled LibreOffice and localizes transient state.

Complete primary Run #83 (`33497784837`), job `99823839704`, commit `355c0cf5cfe7afaadd89933a0aa3fb13456ebb83`, passed every prior gate plus direct/shim DOCX→PDF and PDF→DOCX, normal relocation with spaces, cleanup and real Stirling Office→PDF/PDF→DOCX routes. LibreOffice + unoconvert are formally accepted.

### Poppler 26.02.0 — accepted

PDF_Tunner pins `oschwartz10612/poppler-windows` release `v26.02.0-0`, archive SHA-256 `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`. The package includes `pdftohtml.exe`, `pdfinfo.exe` and `pdfimages.exe` under `tools/poppler/Library/bin/`.

Complete primary Run #86 (`33507551477`), job `99855128441`, commit `1b2bfdc4e99d87aa899a0701291db496f740f7ab`, passed every earlier and Poppler gate, including isolated resolution, real command execution, relocation and Stirling PDF→HTML. Poppler is formally accepted.

### WeasyPrint 69.0 — accepted

Pinned Stirling 2.14.3 resolves literal `weasyprint`, requires version `58.0` or newer and invokes `weasyprint -e utf-8 -v --pdf-forms INPUT OUTPUT`. PDF_Tunner pins official Kozea WeasyPrint `69.0` Windows asset `weasyprint-windows.zip`, published 2026-06-02, archive size `29,832,155` bytes and SHA-256 `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`.

The official backend is staged at `tools/weasyprint/weasyprint.exe`; native package-relative shim `tools/bin/weasyprint.exe` forwards the complete CLI and localizes PyInstaller/child `TEMP`, `TMP` and `TMPDIR` to `data/tmp/weasyprint/run-<pid>-<timestamp>/`, cleaning the invocation directory on exit. WeasyPrint stays isolated from the accepted Python/OCRmyPDF environment.

Run #94 (`33666446582`), job `100369276881`, commit `3afffbc52eb2450eede8ea112ce0628a0bd8b3c4`, produced bounded startup diagnostics proving the backend itself was healthy, both real WeasyPrint routes executed, and the failure was validator-only: Stirling rendered dependency versions as `69.0.0` / `58.0.0` while the validator expected `69.0` / `58.0`. Corrective commit `a7a118e852277069c8ab13cc2f25121f9be87fea` changed only that semantic log assertion; payload, hash, shim, PATH, CLI, endpoints, timeout and prior gates remained unchanged.

**Complete primary Run #95 (`33695530172`), job `100463449110`, commit `a7a118e852277069c8ab13cc2f25121f9be87fea`, passed every step and formally accepts WeasyPrint 69.0.** The run passed isolated package-only WeasyPrint validation, real HTML→PDF, relocation with spaces, live Stirling HTML→PDF and Markdown→PDF, dependency-group logging, every previously accepted dependency gate, backend startup, portable state/process cleanup, final layout validation and ZIP generation.

Run #95 generated and validated `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`, size `1,553,629,801` bytes, SHA-256 `CFD09D41CC5E074B7CEF1885F5A32ED58F08E2FE6FB9EEBC0C0AA07B2A16C0FE`. The ZIP itself was not uploaded. Retained lightweight artifact `9872300027`, `PDF_Tunner-Windows-x64-CI-evidence`, is `6,055` bytes with Actions digest `sha256:e54704632653500d4514dd41c24340d598c66de547ac81e1a06e8d3d30d3468f`, expires 2026-09-09, and includes WeasyPrint provenance/checksums plus existing package evidence. Layout summary: `30,051` package files / `3,569,719,817` payload bytes.

### Calibre 9.14.0 / `ebook-convert` — candidate, focused validation green

Pinned Stirling 2.14.3 resolves literal `ebook-convert`. Its PDF→EPUB route invokes Calibre with `--pdf-engine pdftohtml`, so the candidate deliberately reuses the already accepted package-local Poppler; eBook→PDF accepts EPUB/MOBI/AZW3/FB2/TXT/DOCX and can subsequently use Ghostscript optimization.

Candidate payload: official Calibre Windows x64 MSI `calibre-64bit-9.14.0.msi`, URL `https://download.calibre-ebook.com/9.14.0/calibre-64bit-9.14.0.msi`, pinned SHA-256 `4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d`. CI performs MSI administrative extraction only and stages the runtime under `tools/calibre`; it does not install Calibre on the runner.

A native package-relative `tools/bin/ebook-convert.exe` launcher forwards the exact Stirling CLI to `tools/calibre/ebook-convert.exe`, places config/cache under `data/calibre/`, creates per-invocation temp under `data/tmp/calibre/`, sets `CALIBRE_NO_DEFAULT_PROGRAMS=1`, and removes invocation temp after exit. Candidate validation requires AMD64 identity, package-first command resolution, exact version, TXT→EPUB, EPUB→PDF, Stirling-shaped PDF→EPUB through bundled Poppler, no host-profile leakage/orphan processes and relocation to a path containing spaces. Real Stirling `/ebook/pdf` and `/pdf/epub` routes remain required in the complete primary regression before acceptance.

**Focused candidate Run #1 (`33743422083`), job `100610347852`, commit `e329e3c128ab9d26437f5dffad8a47e80b0c6362`, passed all focused gates.** It proved authenticated MSI administrative extraction, package-only `ebook-convert`, direct TXT→EPUB and EPUB→PDF, Stirling-shaped PDF→EPUB through bundled Poppler, package-local state/process cleanup and relocation to a path containing spaces. Lightweight artifact `9888693480` is `1,469` bytes with Actions digest `sha256:4fcec246dd9a55263bd4b609a1053d18e72908dd40a7ad9c9ca291480c3c2694`, expires 2026-09-06. This is candidate evidence, not formal acceptance.

## Architecture and portable boundary

PDF_Tunner uses Stirling's own Tauri desktop app in `frontend/editor/src-tauri`. Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`.

State is localized component by component; do not globally replace user-profile environment variables before Tauri/WebView2 initializes. Key paths:

- Stirling backend config/logs/working state -> `data/`;
- Java temp -> `data/tmp/`;
- WebView2 profile -> `data/webview2/`;
- Tauri logs/store/cookies/window state -> `data/tauri/...`;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- Tesseract models -> `tools/tesseract/tessdata/`;
- Python/OCRmyPDF -> `tools/python/`; OCRmyPDF temp -> `data/tmp/ocrmypdf/`; Python cache -> `data/python-cache/`;
- LibreOffice -> `tools/libreoffice/`; `unoconvert.exe` -> `tools/bin/`; transient state -> package-local temp/profile paths;
- Poppler -> `tools/poppler/Library/bin/`;
- WeasyPrint backend -> `tools/weasyprint/`; literal command shim -> `tools/bin/weasyprint.exe`; per-invocation temp -> `data/tmp/weasyprint/`;
- Calibre -> `tools/calibre/`; literal command launcher -> `tools/bin/ebook-convert.exe`; config/cache -> `data/calibre/`; per-invocation temp -> `data/tmp/calibre/`.

Portable mode skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## Validation and CI policy

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. `--version` alone is never sufficient; require real operation and package-first isolation wherever practical.

Focused Calibre Run #1 is green and the focused workflow is now retired. A branch-only one-shot integration workflow advances `pdf-tunner/windows-portable-v1` with one atomic commit containing only permanent Calibre scripts, the primary workflow changes, bounded diagnostics and README+AGENTS; candidate-only workflow/script files are explicitly excluded from that primary commit. The resulting single development-branch push triggers the complete primary regression.

The first integration attempt, Run `33744277709` / job `100613069064`, aborted before any write to `pdf-tunner/windows-portable-v1`: its final package-validation selector matched three legitimate WeasyPrint validation blocks instead of exactly one. The corrected integrator anchors that insertion to the unique final LibreOffice-to-`data/` cleanup boundary. No Calibre payload, hash, launcher, endpoint or acceptance gate was changed.

The second integration attempt, Run `33747081554` / job `100621923550`, also aborted before any write to `pdf-tunner/windows-portable-v1`: the diagnostics selector matched the same `Stirling-PDF` literal in two inventories. The next correction scopes that replacement to the complete unique `$hostProfilePaths` block. Again, no Calibre payload, hash, launcher, endpoint or acceptance gate changed.

The third integration attempt, Run `33747627484` / job `100623670622`, passed every transformation and structural guard, created the intended seven-file local commit, and failed only when GitHub rejected the Actions token from updating `.github/workflows/pdf-tunner-windows-portable.yml` without `workflows` permission. The integration strategy therefore now publishes exact generated workflow/diagnostics snapshots outside `.github/workflows/` and lets the GitHub connector promote those exact blobs atomically. This changes no Calibre payload or validation gate.

Ordinary CI always builds and validates the portable ZIP but uploads only lightweight evidence. The multi-gigabyte ZIP, wheelhouses and caches are not ordinary artifacts. Failure diagnostics are text-only and bounded; the startup collector prioritizes package-local backend log tails and concise process/state inventories. No final Release is created before complete v1 acceptance and explicit user authorization.

## Remaining v1 roadmap

1. **Calibre/`ebook-convert`** focused validation is green; complete primary acceptance is the active gate.
2. `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate/package `jbig2enc` if viable; establish viable portable RAR/CBR support or document the limitation; add any further dependency exposed by exact pinned-source audit.
3. Representative E2E operations across OCR, Office, HTML/URL -> PDF, accepted Poppler and WeasyPrint, Calibre/EPUB, Python/OpenCV and representative Stirling API families; HTML/URL/base-URL and EML breadth remains here even though WeasyPrint itself is accepted.
4. Non-Enterprise parity audit against Stirling 2.14.3.
5. Final branding and portability audits.
6. CI/repository cleanup, including physical removal of retired focused/diagnostic mechanisms and downstream diff hygiene review.
7. Final docs/provenance/version/hash record.
8. Integrate to `main` without reopening old PR #1.
9. Publish the clean v1 portable ZIP only after all gates and explicit authorization, then perform the manual clean-machine Windows 10/11 checklist.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**
