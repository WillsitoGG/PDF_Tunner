# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository.

## Identity, base and target

PDF_Tunner is the real fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

- Pinned upstream version: `2.14.3`
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: Windows 10/11 x64 portable ZIP, extract and run without installation.
- Preserve Stirling non-Enterprise functionality unless explicitly removed.
- Bundle required runtimes/dependencies whenever technically and legally viable.
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
11. Never weaken a functional, portability, containment, provenance or parity gate merely to get green.
12. Remove development-only focused/integration/diagnostic mechanisms before final `main` integration.
13. Do not reopen old PR #1 as the v1 release integration vehicle.
14. Do not publish a final Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete, and never without explicit user authorization.
15. Ordinary CI must never upload the multi-gigabyte portable ZIP; retain lightweight evidence only.

## Continuity protocol

Before writes in a resumed conversation:

1. recover the most recent PDF_Tunner handoff;
2. read the project `00.` rules plus current README and AGENTS;
3. verify live development-branch HEAD, latest primary Actions run, PR state and Release state;
4. carry accepted/closed, active candidate, next block and broader roadmap explicitly;
5. never treat one immediate dependency as the only remaining work;
6. at each accepted milestone record commit, Run/job, artifact/digest where relevant, next candidate and remaining roadmap in README + AGENTS;
7. when resuming an Actions run, inspect its exact run ID and terminal conclusion; do not rely on a commit status alone, because Run #117 succeeded while the status bridge remained `pending` after its startup-only publication;
8. before final Release re-audit against the full original PDF_Tunner objective;
9. when an Actions job is active, keep the requested work moving: poll the exact run ID and latest attempt until terminal, send concise progress updates while waiting, and continue independent audits rather than leaving the turn without a result;
10. on a failure, inspect the exact failed step and lightweight diagnostics first. Retry only failed jobs when evidence shows a transient external issue; avoid pushing another commit to the same concurrency group while the heavy job is running, since the workflow cancels its in-progress run.

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
- Python/OCRmyPDF/NumPy/OpenCV → `<portable>/tools/python`; portable CFF conversion script → `<portable>/tools/python/cff/convert_cff_to_ttf.py`; OCRmyPDF child temp → `<portable>/data/tmp/ocrmypdf`; Python cache → `<portable>/data/python-cache`;
- LibreOffice → `<portable>/tools/libreoffice`; `unoconvert.exe` → `<portable>/tools/bin`;
- conversion fonts → `<portable>/tools/libreoffice/share/fonts/truetype`; metadata → `<portable>/tools/fonts`;
- Poppler → `<portable>/tools/poppler/Library/bin`;
- WeasyPrint → `<portable>/tools/weasyprint`; shim → `<portable>/tools/bin/weasyprint.exe`;
- Calibre → `<portable>/tools/calibre`; launcher → `<portable>/tools/bin/ebook-convert.exe`; config/cache/temp remain package-local;
- OCRmyPDF auxiliaries → `<portable>/tools/bin/unpaper.exe` with required sibling DLLs and `<portable>/tools/bin/pngquant.exe`;
- jbig2enc → `<portable>/tools/jbig2enc/jbig2.exe`;
- optional licensed/user-supplied RAR encoder → `<portable>/tools/rar/rar.exe`; never bundle it without a valid redistribution basis;
- embedded VeraPDF → inside `app.jar`; bundled JRE must include `jdk.dynalink`;
- skip `pdf-tunner://` deep-link registration in portable mode.

The Tauri bootstrap prepends `tools/bin`, Python, LibreOffice, Tesseract, Ghostscript, qpdf, Poppler, ImageMagick, Calibre, pngquant, unpaper, `tools/rar` and `tools/jbig2enc` before inherited host PATH when those package directories exist. Dependency validation must prove the intended package copy is the one actually resolved.

## External dependency source of truth

For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- controllers/services executing each feature;
- exact accepted third-party package source when a dependency is mediated through OCRmyPDF or another bundled runtime;
- embedded dependency declarations in `app/core/build.gradle` when there is no external executable.

Direct runtime probes include Ghostscript `gs`, OCRmyPDF `ocrmypdf`, LibreOffice `soffice`, WeasyPrint `weasyprint`, Poppler `pdftohtml`, UNO `unoconvert`, qpdf `qpdf`, Tesseract `tesseract`, Calibre `ebook-convert`, ImageMagick `magick`, Python, OpenCV import, OCRmyPDF ToolProbe for `unpaper`/`pngquant`/`jbig2enc`, real API-level VeraPDF verification and the explicit RAR/CBR contract below.

## Accepted layers and evidence

| Layer | Acceptance evidence |
| --- | --- |
| Native portable/Tauri containment | consolidated proof includes Run `32825188381` |
| Fixed WebView2 `151.0.4129.101` x64 | Run #62 `33058462619` |
| qpdf `12.4.0` | Run #66 `33086404875` |
| ImageMagick `7.1.2-30` | Run #67 `33092698357` |
| Ghostscript `10.07.1` | Run #68 `33104114920` |
| Tesseract `5.5.3` / CLI `5.5.3.20260724` | Run #70 `33122172947` |
| Python `3.12.14` + OCRmyPDF `17.10.0` | Run #77 `33201568275` |
| LibreOffice `26.2.5` + native `unoconvert` | Run #83 `33497784837` |
| Poppler `26.02.0` | Run #86 `33507551477` |
| authenticated Python lock + NumPy `2.5.2` | Run #90 `33530454097` |
| OpenCV `4.14.0.94` / runtime `4.14.0` | Run #92 `33557169326` |
| WeasyPrint `69.0` | Run #95 `33695530172` |
| Calibre `9.14.0` | Run #96 `33748509811` |
| unpaper `6.1` + pngquant `2.17.0` | Run #99 `33786563784` |
| conversion fonts | Run #103 `33896293861`, job `101099606785`, commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f` |
| embedded VeraPDF `1.30.2` | Run #105 `33956010668`, attempt 2, job `101283384499`, commit `e2c2e0544bbd0f092980386b0e764550146c799e` |
| **jbig2enc `0.32`** | **Run #108 `34138754142`, job `101795708391`, commit `64f86ce6f567f49be1e677697221c52a8b26131f`** |
| **RAR / CBR contract** | **Run #117 `37295728617`; embedded CBR→PDF, optional package-first PDF→CBR encoder, no bundled `rar.exe`** |
| **CFF PDF-JSON conversion** | **Run #119 `37358156494`, job `111925742002`, commit `71a34bb065e419869cff96006ae9df06288d1f20`; real 2,221-glyph conversion + relocation** |
| **PDF→WebP Python/Poppler parity** | **Run #120 `37459765068`, job `112256117833`, commit `098ab25f2ed95d6f8bc290b053d2ff5f2cf148f2`; `pdf2image 1.17.0` + package-local Poppler + real E2E/relocation** |

### Fixed provenance values that must not drift silently

- WebView2 CAB SHA-256: `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`
- qpdf archive SHA-256: `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`
- ImageMagick archive SHA-256: `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`
- Ghostscript installer SHA-256: `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`
- Tesseract installer SHA-256: `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`
- Python archive SHA-256: `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`
- OCRmyPDF wheel SHA-256: `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`
- Python dependency lock SHA-256 (29-package accepted baseline from Run #120): `ccc4a3e0e44cafb5f12ecd3e72f52e06016e31dbd9dd86292bcb537ba29e4e7c`
- pdf2image `1.17.0` wheel SHA-256: `ecdd58d7afb810dffe21ef2b1bbc057ef434dabbac6c33778a38a3f7744a27e2`
- NumPy wheel SHA-256: `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`
- OpenCV wheel SHA-256: `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`
- LibreOffice MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`
- Poppler archive SHA-256: `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`
- WeasyPrint archive SHA-256: `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`
- Calibre MSI SHA-256: `4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d`
- unpaper archive SHA-256: `a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65`
- pngquant archive SHA-256: `bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d`
- Noto CJK `Sans2.004` Regular subset SHA-256 values remain exactly those documented in README history; do not change them without new authenticated evidence.
- jbig2enc Meson `1.10.0` wheel SHA-256: `4b27aafce281e652dcb437b28007457411245d975c48b5db3a797d3e93ae1585`.
- jbig2enc source tag `0.32` resolves exactly to commit `309b2d55c7dfdcf0ab6afccb6d88834afc0bf2c0`.

## Accepted milestone — jbig2enc 0.32

Run #106 (`33967722557`) reproduced the jbig2enc runtime-E2E failure. Commit `4b33063c721ea9eb58cddd955f8b306adb83a169` added phase-qualified observability, and Run #107 (`34122536256`, job `101743654235`) proved source pinning, Meson setup/compile/tests/install, staging and initial ToolProbe had passed; only the runtime E2E failed because its test-only PATH hid accepted `tools/bin/pngquant.exe`.

Commit `64f86ce6f567f49be1e677697221c52a8b26131f` added `tools/bin` to the isolated runtime E2E and explicitly required packaged pngquant, mirroring the real bootstrap without weakening the `/JBIG2Decode` gate.

Run #108 (`34138754142`, job `101795708391`) passed the complete primary workflow and accepts jbig2enc 0.32. Evidence:

- commit `64f86ce6f567f49be1e677697221c52a8b26131f`;
- ZIP SHA-256 `9F4334CB90B79457D3515877308DC3A25E521132A3B5130E79ABA650CAE8C5CE`;
- ZIP size `1,911,812,538` bytes;
- layout `31,618` files / `4,392,280,088` payload bytes;
- lightweight artifact `10026083402`, size `7,583`, digest `sha256:04170eabf8166d25b24d57977cbbd54edbe0501b94f4b13a59cbe0fd9708dbe4`;
- multi-gigabyte ZIP not uploaded.

jbig2enc is closed/accepted; do not reopen it without new evidence.

## Latest accepted milestone — CFF PDF-JSON conversion

Pinned Stirling 2.14.3 configures PDF-JSON CFF conversion for Linux container paths. In PDF_Tunner portable mode, only those exact upstream defaults are redirected to package-local \`tools/python/python.exe\` and \`tools/python/cff/convert_cff_to_ttf.py\`; explicit custom configuration remains unchanged.

Run #119 (\`37358156494\`, job \`111925742002\`, commit \`71a34bb065e419869cff96006ae9df06288d1f20\`) passed the complete primary workflow. Acceptance evidence:

- converter script SHA-256 \`9d57d9ae721c97ff7581099c1dce55a1d3350b255f2b198055bf0e1c5bc3d15c\`;
- real package-local conversion rebuilt a valid 2,221-glyph OpenType-CFF font;
- the same conversion passed after relocation to a Windows path containing spaces;
- ZIP SHA-256 \`80821D577F7F4B8246AD69E95CDCCE9140D85ACA5AFE6EAB0ED3D60A2FCB1BE1\`, size \`1,911,877,412\` bytes;
- layout \`31,621\` files / \`4,392,452,052\` bytes;
- lightweight artifact \`11366833930\`, size \`7,758\`, digest \`sha256:632172c024a509f811443ff48501be974d1bcfdaf60c1846198a903facf89eb6\`.

CFF PDF-JSON portability is closed/accepted; do not reopen it without new evidence.

## Accepted contract — RAR / CBR

Pinned Stirling behavior is asymmetric and must remain explicit:

- CBR→PDF uses embedded `junrar` and requires no external RAR executable.
- PDF→CBR executes real RAR CLI as `rar a -m5 -ep1 <output.cbr> <page PNGs>`.
- Never substitute ZIP/CBZ bytes under a `.cbr` extension.
- Do not bundle standalone `rar.exe` unless a valid redistribution basis is obtained.
- The intended optional user path is package-first `<portable>/tools/rar/rar.exe`.

PDF_Tunner-specific portability adaptation:

- RAR is the only dependency treated as **lazy optional** in `ExternalAppDepConfig`.
- If `rar` is absent during startup, do not permanently disable the RAR endpoint group. Keep the group enabled so `ProcessBuilder` can resolve a package-local encoder from the already configured `tools/rar` PATH entry when PDF→CBR is actually invoked.
- This permits a legitimately supplied `tools/rar/rar.exe` to be added before or after application launch without restarting solely to re-enable the endpoint.
- If no encoder exists at invocation time, PDF→CBR must fail explicitly. Do not fake CBR with ZIP/CBZ bytes.
- All other Stirling dependency groups retain their existing startup-disable semantics.

Acceptance implementation:

- `.github/scripts/validate-rar-cbr.ps1` generates a deterministic **real RAR3** fixture internally; no network fixture/download is allowed.
- Fixture: 146 bytes, one stored `page_001.png`, SHA-256 `f3d3e772d72fc274146f45eaf8c37b97dad35f5add83b22c0d1e7c5c603373d0`.
- Backend logs must not report `Disabling group: rar` when the package starts with no `rar.exe`.
- With no `rar.exe`, `/api/v1/convert/cbr/pdf` must return a valid PDF accepted by packaged qpdf.
- `.github/scripts/rar-probe.rs` is CI-only. After the backend is already running, it is copied temporarily to `tools/rar/rar.exe`, records its own absolute executable path and every argument, validates `a -m5 -ep1`, `.cbr` output and PNG inputs, then writes only `PDF_TUNNER_RAR_PROBE_ONLY`.
- The probe is deliberately **not** a RAR encoder and must never be shipped or treated as functional PDF→CBR output.
- The real PDF→CBR route must dynamically resolve the newly supplied package-local probe without a backend restart.
- After removing the probe, `/api/v1/convert/pdf/cbr` must fail explicitly; no silent ZIP fallback is permitted.
- Final validation scans the portable tree and fails if any `rar.exe` leaked into the package.

### Run #115 failure diagnosis

Run #115 (`34218818659`, commit `f7e42a7c5bddebbb67ebc1050a54bd19f2bb6f80`) passed steps 1–34 and failed only in step 35 (`Start PDF_Tunner and validate real backend`). Bounded startup diagnostics recorded `Missing dependency: rar`, confirming that upstream's one-time startup dependency decision disabled the RAR route before the CI-only probe was inserted. Independent reproduction of the deterministic fixture logic also proved the original expected SHA `136cda2e...` was wrong; the exact 146-byte output is `f3d3e772d72fc274146f45eaf8c37b97dad35f5add83b22c0d1e7c5c603373d0`.

The correction is deliberately narrow: special-case only `rar` as lazy optional and correct the deterministic fixture hash. Do not weaken any other dependency, functional, portability, containment or packaging gate.

Run #116 attempt 3 (`34345749975`, job `111702616470`, commit `98f458e44258eaf9bf120397733f68a7e4dba4ff`) passed the complete live-backend block, including deterministic real CBR→PDF, package-first PDF→CBR probe invocation, explicit no-encoder failure and no-`rar.exe` package check. The full primary workflow still failed at step 36, portable window-state persistence: first launch saved position `(111,87)` and client size `824×581`; the second-launch probe measured `(0,0)`, outer `16×16`, client `0×0` after 30 seconds. The probe currently chose the first visible process-owned HWND without identifying its title/class, so the selected handle may be an auxiliary window. Bounded diagnostics artifact `11338690381` (SHA-256 `86f7238911eb5c74a651b2cd316f76974dc4ab4c2ce77dfca9708fb3c3dec976`, 36,066 bytes; expires 2026-10-08) contains the app/backend logs and process snapshot but not HWND titles/classes.

The portable-window test is being tightened to target the configured main-window title `PDF_Tunner` and to list all visible HWND titles, classes and dimensions if startup or restoration fails. Keep the saved-geometry assertions unchanged. If the actual titled main window remains `16×16`, investigate the native restore lifecycle; do not accept the RAR/CBR candidate until the entire primary workflow is green.

Run #117 (`37295728617`) passed the corrected window-state gate and the complete primary workflow with the earlier accepted gates enabled; this satisfies the RAR/CBR acceptance condition recorded in the current handoff.

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency or functional layer moves to accepted only when the complete primary workflow is green with every earlier accepted gate enabled. Record commit SHA, Run/number, job ID, exact source/version/hash or embedded identity, and artifact/digest when relevant. Standalone `--version`, file existence or a narrow direct probe alone is never acceptance.

Before causing a new heavy regression, confirm no useful run is queued/in-progress. Do not rerun blindly after failure: inspect jobs/logs and bounded diagnostics, establish a concrete root cause, apply the smallest justified correction, then run one complete primary regression. Do not increase timeouts blindly or weaken gates.

## CI artifact storage policy

The primary workflow builds and validates the portable ZIP but ordinary CI uploads only lightweight evidence: package hash/size, provenance, dependency lock/inventory and layout summary. Do not upload the portable ZIP, Python wheelhouses, dependency archives, jbig2 build trees or caches during ordinary iterations. Final portable ZIP is a Release asset only after all v1 gates and explicit user authorization.

## Remaining v1 roadmap — do not collapse

### A. External toolchain / embedded runtime parity

1. **RAR/CBR portability contract** — accepted by Run #117;
2. **CFF PDF-JSON font conversion** — accepted by Run #119;
3. **PDF→WebP Python/Poppler parity** — accepted by Run #120;
4. **Secure CFF→TTF reconstruction** — active candidate: the package-local Python converter must produce actual TTF outlines using fontTools 4.64.0's bundled Cu2QuPen path, preventing the automatic PDF-reconstruction path from needing FontForge;
5. finish exact pinned-source dependency parity audit and close any remaining concrete dependency gap.

### B. Functional validation

Representative E2E must cover Office→PDF and supported PDF→Office, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, VeraPDF, jbig2enc, RAR/CBR behavior and representative Stirling API families. Prove runner-installed software is never satisfying package tests.

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

## Current handoff — 2026-10-06

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python 3.12.14 + OCRmyPDF 17.10.0; authenticated 29-package Python lock; NumPy 2.5.2; OpenCV `4.14.0.94`; `pdf2image 1.17.0` + PDF→WebP/Poppler parity; LibreOffice 26.2.5 + native `unoconvert`; Poppler 26.02.0; WeasyPrint 69.0; Calibre 9.14.0; unpaper 6.1 + pngquant 2.17.0; conversion fonts; embedded VeraPDF 1.30.2 E2E; **jbig2enc 0.32**; **RAR/CBR portability contract**; **CFF Python PDF-JSON conversion**.

Latest complete green primary: **Run #120** (`37459765068`), job `112256117833`, commit `098ab25f2ed95d6f8bc290b053d2ff5f2cf148f2`; ZIP SHA-256 `CC51384F82CE3F05E11329294659DE548996F7299DBEFD1A28D7ED7851E6FC4B`; size `1,911,924,279` bytes; layout `31,639` files / `4,392,524,882` bytes; lightweight artifact `11414435818`, size `7,854`, digest `sha256:d81fe9e35ea3cdabd88c7259c9cbb5eea3c2a4ea3ce9e570d141350a2f0f7a75`.

Run #120 accepts the PDF→WebP gap: authenticated `pdf2image 1.17.0`, package-local Poppler `pdfinfo`/`pdftoppm`, Stirling's real `png_to_webp.py` PDF-mode E2E, relocation to a path with spaces and live-backend regression all passed with every earlier gate enabled.

Active candidate: **secure CFF→TTF reconstruction without bundled FontForge**. The audit proved `PdfJsonConversionService` invokes `convertCffUsingFontForge` when the Python converter yields OTF rather than TTF. Instead of packaging the official Windows FontForge 20251009 build, which is affected by current 2025 memory-safety advisories including NVD CVE-2025-15279, PDF_Tunner will reuse the already authenticated fontTools 4.64.0 implementation of `Cu2QuPen` to convert the reconstructed OTF-CFF outlines to true TTF. CI must prove exact sfnt TrueType bytes `00 01 00 00`, `glyf`/`loca`, absence of `CFF `, exactly 2,221 fixture glyphs and relocation. Keep the PowerShell-embedded Python assertion single-escaped so Python evaluates the binary signature rather than a literal backslash sequence. Explicit custom/upstream FontForge configuration stays supported; PDF_Tunner does not bundle the vulnerable executable.

Continue the exact pinned-source dependency audit after FontForge, then representative E2E and final branding/portability/cleanup/release-readiness. FFmpeg remains disabled in pinned Stirling 2.14.3 because of CVE concerns; do not bundle or re-enable it without a separate security review.

Long-run protocol: exact Actions run ID/latest attempt is the primary tracking key; terminal Actions conclusion outranks commit status; keep concise progress updates flowing and continue independent audit work while CI is active; do not push a replacement heavy run while a useful run is still active.

No final Release has been published.
