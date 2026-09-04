# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository.

## Identity, base and target

PDF_Tunner is the real fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

- Pinned upstream version: `2.14.3`
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: Windows 10/11 x64 portable ZIP, extract and run without installation.
- Preserve Stirling non-Enterprise functionality unless explicitly removed.
- Bundle required runtimes/dependencies whenever technically viable.
- Keep runtime config/cache/log/temp/state inside the portable tree as far as underlying Windows APIs permit.
- Keep the downstream delta small and easy to rebase on Stirling upstream.
- `main` remains the clean pinned upstream base during v1 development.
- No final PDF_Tunner v1 Release exists yet.

## Mandatory repository rules

1. Preserve Stirling's root structure; do not reorganize the fork into generic archive/source roots.
2. Keep `main` clean: no generated builds, logs, abandoned experiments, one-shot triggers or temporary artifacts.
3. Preserve upstream behavior unless the user requests removal or functionality is outside target.
4. Compilation alone is never validation. Validate the assembled portable app and real operations.
5. Never archive failed/intermediate builds as release history.
6. Keep SHA-256/provenance and exact dependency identity reproducible.
7. **Every PDF_Tunner-specific change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
8. Heavy CI must use branch/workflow-specific concurrency with `cancel-in-progress: true`.
9. Use at most one automatic trigger per heavy workflow unless technically necessary.
10. Avoid redundant complete regressions; inspect failures and apply the smallest justified correction first.
11. Remove development-only focused/integration/diagnostic mechanisms before final `main` integration.
12. Do not reopen old PR #1 as the v1 release integration vehicle.
13. Do not publish a final Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete, and never without explicit user authorization.
14. Ordinary CI must never upload the multi-gigabyte portable ZIP; retain lightweight evidence only.

## Continuity protocol

Before writes in a resumed conversation:

1. recover the most recent PDF_Tunner handoff;
2. read the project `00.` rules plus current README and AGENTS;
3. verify live development-branch HEAD, latest primary Actions run, PR state and Release state;
4. carry accepted/closed, active candidate, next block and broader roadmap explicitly;
5. never treat one immediate dependency as the only remaining work;
6. at each accepted milestone record commit, Run/job, artifact/digest where relevant, next candidate and remaining roadmap in README + AGENTS;
7. before final Release re-audit against the full original PDF_Tunner objective.

## Architecture and portable boundary

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`. Do not restore the old `PDF_Tunner_Legacy` .NET/WebView2 launcher architecture.

Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable.

Do **not** globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before Tauri/WebView2 initializes. Use component-specific localization:

- `PDF_TUNNER_PORTABLE_ROOT` → executable directory;
- Stirling app data → `<portable>/data`;
- Java temp → `<portable>/data/tmp` through `JAVA_TOOL_OPTIONS`;
- WebView2 user data → `<portable>/data/webview2`;
- Tauri logs/store/window-state/http cookies → `<portable>/data/tauri/...`;
- ImageMagick → `<portable>/tools/imagemagick`, temp → `<portable>/data/tmp/imagemagick`;
- Ghostscript → package-first `<portable>/tools/ghostscript/bin`;
- Tesseract → package-first `<portable>/tools/tesseract`, `TESSDATA_PREFIX=<portable>/tools/tesseract/tessdata`;
- Python/OCRmyPDF/NumPy/OpenCV → `<portable>/tools/python`; OCRmyPDF child temp → `<portable>/data/tmp/ocrmypdf`; Python cache → `<portable>/data/python-cache`;
- LibreOffice → `<portable>/tools/libreoffice`; native source-compatible `unoconvert.exe` → `<portable>/tools/bin`;
- conversion fonts → `<portable>/tools/libreoffice/share/fonts/truetype`; metadata → `<portable>/tools/fonts`;
- Poppler → `<portable>/tools/poppler`, executables under `Library/bin`;
- WeasyPrint → `<portable>/tools/weasyprint`; package-relative literal shim → `<portable>/tools/bin/weasyprint.exe`; temp → `<portable>/data/tmp/weasyprint`;
- Calibre → `<portable>/tools/calibre`; package-relative literal launcher → `<portable>/tools/bin/ebook-convert.exe`; config/cache → `<portable>/data/calibre`; temp → `<portable>/data/tmp/calibre`; set `CALIBRE_NO_DEFAULT_PROGRAMS=1`;
- OCRmyPDF auxiliaries → `<portable>/tools/bin/unpaper.exe` with required sibling DLLs and `<portable>/tools/bin/pngquant.exe`;
- skip `pdf-tunner://` deep-link registration in portable mode.

## External dependency source of truth

For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- controllers/services executing each feature;
- exact accepted third-party package source when a dependency is mediated through OCRmyPDF or another bundled runtime.

Direct runtime probes include:

| Feature | Probe |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` >=58 |
| Poppler HTML | `pdftohtml` |
| UNO conversion | `unoconvert` |
| qpdf | `qpdf` >=12 |
| Tesseract | `tesseract` |
| CBR/RAR | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |
| OCR cleaning | OCRmyPDF `ToolProbe('unpaper')` |
| OCR optimization | OCRmyPDF `ToolProbe('pngquant')` |

Also audit conversion fonts, VeraPDF E2E, `jbig2enc`, RAR/CBR and any additional exact dependency exposed by pinned source.

## Accepted layers and evidence

| Layer | Acceptance evidence |
| --- | --- |
| Native portable/Tauri containment | consolidated AppData/window-state proof includes Run `32825188381` |
| Fixed WebView2 `151.0.4129.101` x64 | Run #62 `33058462619` |
| qpdf `12.4.0` | Run #66 `33086404875` |
| ImageMagick `7.1.2-30` | Run #67 `33092698357` |
| Ghostscript `10.07.1` | Run #68 `33104114920` |
| Tesseract `5.5.3` / CLI `5.5.3.20260724` | Run #70 `33122172947` |
| Python `3.12.14` + OCRmyPDF `17.10.0` | Run #77 `33201568275`, job `98952028665` |
| LibreOffice `26.2.5` + native `unoconvert` | Run #83 `33497784837`, job `99823839704` |
| Poppler `26.02.0` | Run #86 `33507551477`, job `99855128441` |
| authenticated Python lock + NumPy `2.5.2` | complete Run #90 `33530454097`, job `99931980241` |
| OpenCV distribution `4.14.0.94` / runtime `4.14.0` | Run #92 `33557169326`, job `100020722841` |
| WeasyPrint `69.0` | Run #95 `33695530172`, job `100463449110` |
| Calibre `9.14.0` / `ebook-convert` | Run #96 `33748509811`, job `100626447125` |
| **unpaper `6.1` + pngquant `2.17.0`** | **Run #99 `33786563784`, job `100752651171`, commit `8d4d3906f6535c5a0e214cf96948e19de0678a23`** |

### Fixed provenance values that must not drift silently

- WebView2 CAB SHA-256: `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`
- qpdf archive SHA-256: `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`
- ImageMagick archive SHA-256: `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`
- Ghostscript installer SHA-256: `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`
- Tesseract installer SHA-256: `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`
- Python archive SHA-256: `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`
- OCRmyPDF wheel SHA-256: `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`
- accepted 28-package Python lock SHA-256: `ededb999049d81b85527f4d4aa679179e747669df300083d91bc2dd4e14e430f`
- NumPy wheel SHA-256: `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`
- OpenCV wheel SHA-256: `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`
- LibreOffice MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`
- Poppler archive SHA-256: `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`
- WeasyPrint archive SHA-256: `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`
- Calibre MSI SHA-256: `4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d`
- unpaper archive SHA-256: `a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65`
- pngquant Windows archive SHA-256: `bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d`

## Latest accepted milestone — OCRmyPDF auxiliary tools

Complete primary Run #99 (`33786563784`), job `100752651171`, commit `8d4d3906f6535c5a0e214cf96948e19de0678a23`, passed every primary step and formally accepts unpaper 6.1 + pngquant 2.17.0.

The prior failures are closed diagnostic history:

- Run #97 localized the failure to the new auxiliary path after the accepted Python/OCRmyPDF core completed;
- Run #98 artifact `9905244757` captured the exact error at auxiliary line 118: the authenticated official pngquant.org archive self-reports `2.17.0 (September 2021)`, not the incorrectly assumed 3.0.3;
- the fix changed only the expected/measured identity and provenance; archive/SHA, AMD64, package-first, ToolProbe, real wrapper, OCR clean and relocation gates remained intact.

Run #99 generated `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`, size `1,861,405,214` bytes, SHA-256 `5AFD552CFDF4DCEF48151470154541694AAFC5E1DD6650E913D2BDBD6D51496F`. Layout: `31,468` files / `4,303,215,732` payload bytes. Lightweight evidence artifact `9906859658` records `UNPAPER_VERSION=6.1` and `PNGQUANT_VERSION=2.17.0`. The ZIP itself was not uploaded.

unpaper/pngquant are closed/accepted; do not reopen them without new evidence.

## Active candidate — conversion fonts

Pinned Stirling 2.14.3 Linux runtime installs `fonts-dejavu`, `fonts-liberation2`, `fonts-crosextra-caladea`, `fonts-crosextra-carlito`, `fonts-noto-core`, `fonts-noto-mono`, `fonts-noto-extra`, `fonts-noto-cjk`, `fonts-freefont-ttf` and `fonts-terminus`. Its Docker cleanup deletes non-Regular Noto weights.

The accepted official LibreOffice 26.2.5 Windows payload already contains the important Latin/Office conversion baseline. The candidate must prove at staging time that at least Carlito, Caladea, DejaVu Sans and Liberation Sans are physically present under `tools/libreoffice/share/fonts/truetype` before adding anything.

LibreOffice source explicitly notes that its test runtime has no bundled CJK fonts. PDF_Tunner therefore adds only the missing regional CJK regular subsets from upstream `notofonts/noto-cjk` tag `Sans2.004`, directly into LibreOffice's package-local font directory:

- `NotoSansSC-Regular.otf` SHA-256 `faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9`;
- `NotoSansTC-Regular.otf` SHA-256 `5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537`;
- `NotoSansHK-Regular.otf` SHA-256 `8a43afea92bb58dfd9027bd7ac6f5b0b2662e2ffb3e7c1edc02c62b2b21924f1`;
- `NotoSansJP-Regular.otf` SHA-256 `dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073`;
- `NotoSansKR-Regular.otf` SHA-256 `69975a0ac8472717870aefeab0a4d52739308d90856b9955313b2ad5e0148d68`.

The hashes correspond to the pinned `Sans2.004` source files and are independently represented in Noto CJK SPDX/package metadata. Use raw GitHub URLs from that tag, never `main`.

`fonts-freefont-ttf` and `fonts-terminus` are Linux image fallback packages; a repository search finds no named Stirling source dependency probe or feature gate for FreeSans/FreeSerif/Terminus. Do not copy the full Linux font stack by inertia. Acceptance is based on actual conversion behavior and host independence.

### Implementation contract

Preserve the accepted LibreOffice prepare and validation implementations byte-for-byte as:

- `.github/scripts/prepare-libreoffice-core.ps1` = accepted former `prepare-libreoffice.ps1` blob;
- `.github/scripts/validate-libreoffice-core.ps1` = accepted former `validate-libreoffice.ps1` blob.

Keep the existing workflow entry paths as narrow wrappers:

- `prepare-libreoffice.ps1` → accepted core, then `prepare-conversion-fonts.ps1`;
- `validate-libreoffice.ps1` → accepted core, then `validate-conversion-fonts.ps1`.

Do not modify the heavy workflow merely to add this layer unless the wrapper approach proves insufficient.

### Runs #100–#101 failure and diagnostic contract

Run #100 (`33791580636`) and Run #101 (`33858332435`, job `100976698570`, commit `da83d4a2129acba6ccafde58d486c5691c1e9d53`) failed at primary step 32, `Stage LibreOffice portable runtime and native unoconvert shim`; primary steps 1–31 were green in both. Run #101 artifact `9931869873`, digest `sha256:a10a233fb55e2f1c24bc119a682a822b98d7b8231beaccb5c21db77a36785584`, did not contain the expected `conversion-fonts-diagnostic.log` and retained only the previous OCR auxiliary diagnostic.

The accepted core identity has been verified exactly: current `.github/scripts/prepare-libreoffice-core.ps1` and the `.github/scripts/prepare-libreoffice.ps1` used by complete green Run #99 have identical Git blob SHA `ea79085578b488b7a3f7e4f4aa47d3decefad3da`. Therefore do not edit the accepted core without new evidence. The five pinned Noto Sans CJK `Sans2.004` SHA-256 values also remain authenticated and unchanged.

The wrapper must now leave an unconditional package-local phase journal before invoking the core. Required markers are `WRAPPER_START`, `CORE_START`, `CORE_SUCCESS`, `FONTS_START`, `FONTS_SUCCESS`. Core and font phases each have guarded exception capture into `data/logs/libreoffice-stage-diagnostic.log`; if rich diagnostic formatting itself fails, `data/logs/libreoffice-stage-phase.log` must still retain the last phase and a minimal diagnostic-write failure marker. This instrumentation is diagnostic-only and must not alter hashes, sources, accepted core behavior or validation gates.

If the next run fails, inspect the phase journal and line-level diagnostic first. Apply the smallest functional correction only after the failing phase/cause is known; do not guess, increase timeouts blindly, weaken gates or change known-good hashes.

### Conversion-font acceptance contract

1. authenticate every CJK font by exact SHA-256;
2. prove the accepted LibreOffice baseline fonts are physically package-local;
3. fail if matching CJK font files exist in Windows system/user font directories, so the test cannot accidentally rely on host copies;
4. generate a DOCX that explicitly requests Carlito, Caladea, DejaVu Sans, Liberation Sans and all five Noto CJK regional families;
5. convert it with package-local `soffice.com`;
6. use package-local Poppler `pdffonts.exe` to prove requested families are embedded;
7. use package-local `pdftotext.exe` to prove SC/TC/HK/JP/KR text survives conversion;
8. repeat after relocation through paths containing spaces;
9. with the real backend live, post the same DOCX through Stirling `/api/v1/convert/file/pdf` and require the same font/text contract;
10. preserve every earlier primary gate, cleanup and final package evidence.

**Do not call conversion fonts accepted until one complete primary workflow is green with this candidate and every earlier gate enabled.**

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency moves to accepted only when the complete primary workflow is green with every earlier accepted gate enabled. Record commit SHA, Run/number, job ID, exact source/version/hash and artifact/digest when relevant. Standalone `--version`, file existence or a narrow direct probe alone is never acceptance.

Before causing a new heavy regression, confirm no useful run is queued/in-progress. Do not rerun blindly after failure: inspect jobs/logs and bounded diagnostics, establish a concrete root cause, apply the smallest justified correction, then run one complete primary regression. Do not increase timeouts blindly or weaken gates.

## CI artifact storage policy

The primary workflow builds and validates the portable ZIP but ordinary CI uploads only lightweight evidence: package hash/size, provenance, dependency lock/inventory and layout summary. Do not upload the portable ZIP, Python wheelhouses, dependency archives or caches during ordinary iterations. Final portable ZIP is a Release asset only after all v1 gates and explicit user authorization.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. **conversion fonts** — active candidate;
2. explicit VeraPDF E2E;
3. investigate/build/package `jbig2enc` if viable;
4. viable portable RAR/CBR or a concrete documented limitation;
5. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Representative E2E must cover Office→PDF and supported PDF→Office, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, RAR/CBR and jbig2enc if integrated, and representative Stirling API families. Prove runner-installed software is never satisfying package tests.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove retired focused/integration/diagnostic mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish clean v1 ZIP only when all gates are complete and explicitly authorized;
9. manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-09-04

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python 3.12.14 + OCRmyPDF 17.10.0; authenticated Python lock; NumPy 2.5.2; OpenCV `4.14.0.94`; LibreOffice 26.2.5 + native `unoconvert`; Poppler 26.02.0; WeasyPrint 69.0; Calibre 9.14.0; **unpaper 6.1 + pngquant 2.17.0**.

Latest complete green primary: **Run #99** (`33786563784`), job `100752651171`, commit `8d4d3906f6535c5a0e214cf96948e19de0678a23`. ZIP SHA-256 `5AFD552CFDF4DCEF48151470154541694AAFC5E1DD6650E913D2BDBD6D51496F`, size `1,861,405,214`; layout `31,468` files / `4,303,215,732` bytes; evidence artifact `9906859658`.

Failed candidate evidence: **Run #101** (`33858332435`), job `100976698570`, commit `da83d4a2129acba6ccafde58d486c5691c1e9d53`; failed at step 32 after primary steps 1–31 remained green. Artifact `9931869873` did not retain the expected conversion-font diagnostic. Accepted LibreOffice core blob remains exactly `ea79085578b488b7a3f7e4f4aa47d3decefad3da`, identical to Run #99.

Active candidate: **package-local conversion fonts**. Next run is diagnostic-only at the wrapper boundary: identify `CORE_*` versus `FONTS_*` phase, capture exact exception, then apply the smallest functional correction. Once fonts are accepted, proceed to **explicit VeraPDF E2E**.
