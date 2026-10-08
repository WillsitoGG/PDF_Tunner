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
9. after launching a heavy Actions job, capture its exact run ID/attempt once and stop polling; the user will confirm visually when it is terminal. While waiting, only continue independent read-only audits that cannot cancel or replace the active run;
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
| Tesseract `5.5.3` / CLI `5.5.3.20260724`, `eng`/`spa`/`deu`/`fra`/`por`/`chi_sim`/`osd` | Run #123 `37490571449`, job `112361901093`, commit `1c94033ae6883077e84dfc4debefac5f6aac330e` |
| Python `3.12.14` + OCRmyPDF `17.10.0` | Run #77 `33201568275` |
| LibreOffice `26.2.5` + native `unoconvert` | Run #83 `33497784837` |
| Poppler `26.02.0` | Run #86 `33507551477` |
| authenticated Python lock + NumPy `2.5.2` | Run #90 `33530454097` |
| OpenCV `4.14.0.94` / runtime `4.14.0` | Run #92 `33557169326` |
| WeasyPrint `69.0`, HTML/Markdown/EML backend routes | EML acceptance Run #124 attempt 2 `37496831786`, job `112394477890`, commit `4542baa5a59732bb87780403ae4f372dd88764ac` |
| Calibre `9.14.0` | Run #96 `33748509811` |
| unpaper `6.1` + pngquant `2.17.0` | Run #99 `33786563784` |
| conversion fonts | Run #103 `33896293861`, job `101099606785`, commit `1a0ad7b216d2b70b4bff0e4b8c9394b5d666797f` |
| embedded VeraPDF `1.30.2` | Run #105 `33956010668`, attempt 2, job `101283384499`, commit `e2c2e0544bbd0f092980386b0e764550146c799e` |
| **jbig2enc `0.32`** | **Run #108 `34138754142`, job `101795708391`, commit `64f86ce6f567f49be1e677697221c52a8b26131f`** |
| **RAR / CBR contract** | **Run #117 `37295728617`; embedded CBR→PDF, optional package-first PDF→CBR encoder, no bundled `rar.exe`** |
| **CFF PDF-JSON conversion** | **Run #119 `37358156494`, job `111925742002`, commit `71a34bb065e419869cff96006ae9df06288d1f20`; real 2,221-glyph conversion + relocation** |
| **PDF→WebP Python/Poppler parity** | **Run #120 `37459765068`, job `112256117833`, commit `098ab25f2ed95d6f8bc290b053d2ff5f2cf148f2`; `pdf2image 1.17.0` + package-local Poppler + real E2E/relocation** |
| **Secure CFF→TTF reconstruction** | **Run #122 `37472331284`, job `112299193532`, commit `b5947844ea8a4525626dba96099105c2730a4085`; fontTools `4.64.0` Cu2QuPen, real 2,221-glyph TTF + relocation** |

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
- CFF converter script SHA-256 accepted by Run #122: `fb8b7f3d2911512f32760b50ccb593b7f26838c87d9cf9d53b4d3414e6783a85`.
- Tesseract `tessdata_fast` commit remains `87416418657359cb625c412a48b6e1d6d41c29bd`; Run #123 accepted blobs: `deu=97ed7b2b60f2771c07040660ef0f6daf596dc7bf`, `fra=d9e2b2160be0d1ca3b8f1bf2730fae476ef3b4a6`, `por=e9f373e95c66b4bf557c263721ef31f78e5bc301`, `chi_sim=388bac276d033d06e5ed5ba7a7ad14ae58f97dab`.

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

## Latest accepted milestone — secure CFF→TTF reconstruction

The pinned PDF reconstruction path can request a TTF representation after the Python CFF wrapper has produced OpenType-CFF. Rather than bundling FontForge, PDF_Tunner now uses the already authenticated fontTools `4.64.0` Cu2QuPen implementation inside the package-local converter to produce genuine TrueType outlines.

Run #121 (`37471270073`, commit `73e07e12cf647f4a14c50d7194936c8063b3eff0`) failed only because the PowerShell-embedded Python assertion compared against a literal escaped byte sequence. Commit `b5947844ea8a4525626dba96099105c2730a4085` corrected the gate to test the real `00 01 00 00` sfnt signature. Run #122 (`37472331284`, job `112299193532`) then passed the complete primary workflow. Acceptance requires and now proves: real TrueType sfnt signature, `glyf` and `loca`, no `CFF ` table, exactly 2,221 fixture glyphs, relocation, live backend, final package containment and every earlier accepted gate.

Evidence: converter SHA-256 `fb8b7f3d2911512f32760b50ccb593b7f26838c87d9cf9d53b4d3414e6783a85`; ZIP SHA-256 `20DAAAD8F7CA3D1F1FC41FE3D6197A68DB36F8DF5CBB0D462BFE8CB0C5545953`; ZIP size `1,911,909,447` bytes; layout `31,639` files / `4,392,527,297` bytes; artifact `11420435593`, size `7,857`, digest `sha256:93f604924c3ed619936e50c65daac66abffdbc49f21efa213dba8951fffd5400`.

Secure CFF→TTF reconstruction is closed/accepted; do not reopen it without new evidence. Explicit custom FontForge configuration remains upstream-compatible, but PDF_Tunner portable defaults no longer require FontForge.

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
4. **Secure CFF→TTF reconstruction** — accepted by Run #122 using fontTools 4.64.0's bundled Cu2QuPen path; the automatic portable PDF-reconstruction path no longer needs FontForge;
5. **Tesseract upstream language parity** — accepted by Run #123 with pinned `deu`, `fra`, `por`, `chi_sim` plus existing `eng`, `spa`, `osd`, exact blob provenance and real isolated/backend probes;
6. current exact pinned-source pass found no further concrete external/embedded dependency gap; reopen only when code-backed evidence requires it.

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

## Current handoff — 2026-10-08

**Latest complete green primary: Run #129** (`37754829944`, job `113236699098`, dev commit `804cd9950f71a6aaa4db9572ca2276e8080958aa`). Every applicable step passed, including package assembly, all accepted dependency / real-backend / frontend-branding / Windows portability / window-state gates, archive SHA and **the intentional one-day manual-test candidate upload**. Historical functional acceptance Run #128 remains valid and is reconfirmed by #129.

Run #129 **actual ZIP** `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`: SHA-256 `5ABDEE66382A04BE063CD19BB7C8A40C844CB143A778E048D78D9891433EF95C`; `1,916,065,686` bytes; `31,643` files / `4,399,867,226` uncompressed bytes. Full binary artifact **#11541921231** uses `archive: false`, so its artifact digest is identical to the original ZIP SHA. GitHub expires it **2026-10-09 09:53:21 UTC = 11:53:21 Europe/Madrid**. Download: `https://github.com/WillsitoGG/PDF_Tunner/actions/runs/37754829944/artifacts/11541921231`. Evidence artifact **#11541945715**: 7,855 bytes, digest `sha256:2d133a638c83e24a9c18c968b375d6c76798fa6dc51d4849793c0e13ce085266`; contains matching Run ID, commit, ZIP SHA/size and layout.

**Next action:** user downloads and saves the complete ZIP before its one-day expiry; verifies actual file with `Get-FileHash -Algorithm SHA256`; extracts and manually tests on real Windows 10 and ideally Windows 11 x64 according to `RELEASE_STATUS.md`. No clean-machine manual validation has yet been reported; never represent this as accepted. Do not integrate to `main`, publish any Release, or claim overall v1 completion before manual QA and express release authorization. Do not trigger another costly regression solely for documentation.

Upstream pinned `main` remains clean. The exceptional full-ZIP upload is opt-in; ordinary regression uploads lightweight evidence only. After manual sign-off finish final diff/license/provenance review, integrate to `main` via new PR (never PR #1), then seek explicit release authorization.

Long-run protocol: capture exact heavy-run ID once and stop polling, awaiting the user's terminal signal. No background work.


## Windows 10 VM findings / v1 candidate corrections (2026-10-08, pending CI)

Screenshots of the installed Run #129-era candidate in a user's Windows 10 VM show residual **Stirling** marks in the visible React UI, the desktop **Stirling 3.1.0** update popup and a `GET /api/v1/payg/wallet` 404. The existing branding gate covered static Tauri/index/backend metadata, not the shared runtime React `Logo`/`BrandMark` components. The update hook calls the official `https://supabase.stirling.com/functions/v1/updates`, inappropriate for this portable fork. The 404 comes from shared SaaS billing `useWallet`; its exact visible initiating screen must be reproduced before changing route ownership or inventing a wallet response. A separate generic `Network error` toast is not conclusively attributed yet. Strict no-host-write sandbox/registry claims are also pending process-level audit.

The isolated review branch `pdf-tunner/v1-vm-brand-update-fix` addresses only confirmed issues: shared lockup/mark now use the already-packaged PDF_Tunner visual assets; a read-only native `is_pdf_tunner_portable` command suppresses the Stirling update startup check while the portable marker is active; the optional default-app prompt is suppressed in portable mode (explicit settings operation remains upstream-compatible). The special fix has **not yet been tested or accepted** by the complete primary CI. Keep `main` unchanged; do not issue a Release. Next: reproduce wallet/network call, strengthen rendered-UI and filesystem/registry audit; run one complete CI after changes are coherent; never describe a static/source fix as functional acceptance without runner/VM evidence.


### Wallet 404 local-mode guard and runtime-branding QA (2026-10-08, untested)

The common cloud `useWallet` hook calls the PAYG `/api/v1/payg/wallet` endpoint regardless of whether the Tauri desktop uses the local backend. Added a platform seam `walletApiEnabled`: the web/SaaS default permits the real wallet; the desktop override permits it **only in SaaS connection mode**. A local-only Plan view now reports billing unavailable instead of issuing a nonexistent local GET, without inventing billing state or altering the original SaaS contract. The primary branding validation now checks the actual React logo/brand-switcher source and portable update/route gates in addition to packaged static resources. This is a targeted preventive fix, not proof that the separate generic Network error is resolved. Full primary Windows CI and real Windows 10 VM acceptance remain pending.


### Windows 10 VM regression follow-up (2026-10-08; unverified)

Source-side fix branch changes global search text to PDF_Tunner, including translated Stirling brand strings, and refuses three official Stirling update-service requests in a verified portable Tauri process. This complements the pre-existing desktop startup updater gate, the shared visible logo asset replacement, local PAYG 404 guard and portable default-handler prompt suppression. Hosted Windows GUI Run #2 verified candidate download and actual process startup but WebView2 CDP was unavailable; do not count as UI acceptance. The generic network toast and external filesystem/registry write audit still require diagnostics and actual Windows 10 VM checks. Do not publish or optimize package size until functional acceptance.


### Brand switcher preservation and regression gates (2026-10-08; unverified)

PDF_Tunner replaces Stirling visual assets in the shared landing/header components. The original editor/processor switcher is still discoverable on hover/focus/open through a downward chevron; the new asset is inverted in dark mode for contrast. The existing primary CI branding step now checks search text, three native portable upstream-update guards and the brand switcher cue. This is source coverage only; the GitHub Windows compilation and actual UI are not yet retested.


### Scoped Windows host-boundary audit (2026-10-08; CI pending)

Add `.github/scripts/audit-host-boundaries.ps1`, invoked against the **real assembled native PDF_Tunner.exe** by primary Windows CI. It launches with a restricted inherited PATH, polls process-descendant TCP connections and compares before/after fingerprints of product-specific host AppData/TEMP locations and selected HKCU registry keys. It fails on observed external TCP or host-state changes, publishing only a small JSON for three days. **Important limits:** not full file/registry sandbox isolation proof; polling cannot detect transient/short-lived operations and does not capture DNS/UDP. A green result means only that the scoped gates passed. Real Windows 10 VM acceptance (potentially including ProcMon event tracing) remains required. The new CI push is an exceptional `[deliver-portable-candidate]` opt-in: only after all gates pass, preserve the one-day exact Windows ZIP for user VM testing. No Release or main-branch mutation; defer disk-footprint optimization.


### Run #131 audit harness repair (2026-10-08; pending CI)

Run #131 (`37777040239`, commit `3431ee2a`) completed Tauri/backend, dependency and window-state gates, then failed within the NEW host-audit harness **before it monitored anything**: under `Set-StrictMode -Version Latest`, the snapshot routine accessed `.Length` on a `DirectoryInfo` root (not a property of directories). Fix: distinguish file sizes from directories (`<DIR>` sentinel) without changing the fail-closed behavior for observed external TCP or changed product-specific host files/registry keys. Add a `-SelfTest` mode verifying directory snapshot, file creation diff, registry sampling and loopback classification on the Windows runner **before the heavy Java/Tauri/dependency build**. Include the harness in the existing PowerShell syntax preflight. No evidence of an application failure yet. Only after green host-boundary + original gates should the one-day ZIP candidate upload run; no final Release, no main modification. Size optimization deferred.


### Run #132 final Windows CI acceptance and manual handoff (2026-10-08)

The complete Windows x64 portable pipeline **Run #132 attempt 1** (`37781952129`, job `113326983968`, commit `d60587d28304c32c5efc9aa263e2af6628493665`) is **green**. It passed the early host-audit self-test, Tauri/Rust build, real Java/backend/converter/OCR tests, frontend/backend branding checks, package-local dependencies, portable shutdown and second-launch window restore, and the scoped native host-boundary gate. During the 45-second host audit the log reported **6 sampled TCP connections, 0 external connections, 0 changes in watched AppData/TEMP product paths, 0 changes in watched HKCU registry keys; graceful shutdown**. This **does not** prove kernel-level sandbox confinement or the absence of short-lived writes, unsampled traffic, DNS/UDP, or unintended host changes outside the watched locations.

Exceptional **Windows 10 VM candidate ZIP** (not final Release): Actions Run #132 artifact **11554603294**, file `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`, exactly **1,916,053,447 bytes** and SHA-256 **`D2F93495018DD2BC8A362D33F3335649A721235EFE0FE007AD2DDDEDE39896EB`**. Artifact expiry: **2026-10-09 13:48:53 UTC** (15:48:53 Europe/Madrid). Lightweight CI evidence artifact **11554831945**, 7,853 bytes (expires 2026-10-15). Scoped audit JSON artifact **11554457335**, 608 bytes (expires 2026-10-11). Artifacts: https://github.com/WillsitoGG/PDF_Tunner/actions/runs/37781952129 . Do not archive this temporary Actions ZIP as a historical Release.

**Remaining before publication**: clean Windows 10 VM manual run of **this exact SHA-verified ZIP** (do not overwrite old Run #129 folder), screenshots of light/dark PDF_Tunner interface/search and no Stirling update popup, no generic network/PAYG 404 toasts, real offline PDF operations, relocation/relaunch, saved state, local caches/logs and per-process filesystem/registry trace when needed. The old Windows Server GUI automation via WebView2 CDP was inconclusive and is not a substitute. Preserve no-Release/no-`main`-merge policy until user confirms VM acceptance. Package footprint optimization deferred to last phase.


## LISTADO 1 — Incidencias observadas en Windows 10 VM (2026-10-08; aplazadas)

Origen: usuario abrió el candidato de pruebas de **Run #132**, extracto en `C:\Users\Guille\Downloads\PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable`, y aportó cuatro capturas. Se registran literalmente como **LISTADO 1** para **revisar después** de las dos comprobaciones que pidió: (A) trazabilidad de archivos/registro/conexiones fuera de la carpeta portable y (B) inventario de tamaño por herramienta/función. No empezar correcciones ni disparar CI por este registro documental.

1. **Firewall de Windows:** al iniciar, Windows pide permitir el programa como excepción de red. Revisar enlace del backend (si expone un servidor más allá de loopback), presencia de reglas de firewall y si el cuadro de diálogo está justificado para uso solo local. No afirmar todavía cuál de los procesos/puertos lo origina.
2. **Bienvenida residual upstream:** aparece modal morado `Bienvenido a Stirling V2` con referencia `Stirling PDF ya está listo...`; no corresponde a identidad ni bienvenida deseadas para PDF_Tunner. Distinguir esta secuencia de onboarding del anterior aviso separado de actualización del ejecutable.
3. **Inicio de sesión/cloud:** siguiente pantalla dice `Inicie sesión en Stirling` y ofrece Google, GitHub, usuario/contraseña y registro. El usuario no quiere ni necesita registro/login en la modalidad local portable.
4. **Preferencias de modo de conexión:** aparece `SOLO LOCAL` y a la vez un control `Iniciar sesión`; revisar/ocultar acciones cloud y aclarar qué preferencias deberían existir en la edición portable.
5. **Preferencias de actualizaciones:** en General aparecen `Actualizaciones de software`, `Versión Actual del Frontend: 2.14.3`, `Buscar actualizaciones` y `Comportamiento de actualización` (preguntar, instalar automáticamente o saltar). Revisar coherencia con portable y evitar servicios del Stirling oficial. El usuario manifiesta que esas opciones no deberían estar en esta edición; mantener por separado información técnica de versión y atribución legal, si es necesaria.

**Prioridad ahora:** primero comprobar escrituras fuera de `C:\Users\Guille\Downloads\PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable` mediante trazabilidad real (p. ej. Process Monitor de Microsoft, incluyendo Java y WebView2), y después obtener desglose de tamaño de `tools/`, `runtime/`, `libs/` y `data/`. No confundir tamaño por dependencias con tamaño por función de interfaz, pues varios componentes son compartidos. No eliminar herramientas hasta verificar dependencias y pruebas.

### LISTADO 1: ProcMon host-isolation findings (2026-10-08)

Sanitized technical summary only; the original user-supplied CSV is not committed.
Windows 10 Process Monitor captured 346869 events in a roughly two-minute launch and test.
Successful file writes: 16204; inside portable root: 16181; outside: 23.
External writes: WebView2 temporary file (13); Windows Python App Installer redirector log (5); user-facing PDF output in Downloads (5, verify whether explicitly saved).
Java also created temporary performance and socket files in the host Temp directory, some marked for deletion.
Registry events: 201 successful RegSetValue and two genuinely new Shell dialog keys; many RegCreateKey events only opened existing keys.
Network cannot be assessed from the submitted CSV: it contains no TCP/UDP events.

Deferred remediation items 6-11 for LISTADO 1:
6. Find and contain WebView2 host Temp writes and review host WebView2 telemetry keys.
7. Investigate Java performance/socket Temp files and runtime-specific redirection or compatibility flags.
8. Ensure the Java OpenCV probe using python3 runs the packaged Python, never Windows App Installer aliases.
9. Minimize registry changes from native file dialogs and WebView2; determine whether true OS-level sandboxing is necessary.
10. Confirm that documents explicitly exported to user-selected folders are permitted rather than classed as leaks.
11. Add actual TCP/UDP/DNS capture and verify backend listens only on loopback before closing the Firewall warning issue.

Do not change product code or launch CI until the user chooses the isolation contract. Preserve the prior LISTADO 1 items 1-5 and postpone footprint changes.


### LISTADO 1 phase 1A (source branch; not yet tested)

For Windows portable mode only, bind the unauthenticated Java PDF backend to 127.0.0.1, prevent JVM hsperfdata host TEMP files with -XX:-UsePerfData and route only the Java child process and its subprocesses TEMP/TMP to package-local data/tmp. Native Tauri and WebView2 retain genuine OS profile environment variables for compatibility. This is intended to eliminate the LAN-exposed local backend/firewall prompt and Java external temporaries but is not yet compiled or validated. Do not claim strict sandbox isolation; leave other phases pending. No main changes, no Release or CI candidate yet.


### LISTADO 1 phase 1B (source branch; not yet tested)

Stirling Java calls python3 to probe cv2; that name was observed in the Windows VM running the host AppInstallerPythonRedirector.exe. The package now provides `tools/python/python3.exe` as a byte-identical pinned alias next to python.exe, proves the alias imports OpenCV, and includes its SHA in the existing Python manifest and validation. A new live Windows CI test rejects any listener for the embedded no-login Java backend that is not 127.0.0.1 or ::1. The complete converter suite, relocatability, functionality and VM Process Monitor test are pending; no release or main changes.


### LISTADO 1 phase 2: local desktop UI (staged; unverified)

Only on verified native PDF_Tunner portable runs, hide upstream `Welcome to Stirling V2` / SaaS registration first-start modal **before first paint**, suppress the login action in the local-only connection preferences, and omit both software-updates controls/checks and Windows default-PDF-association settings from General. The existing installed desktop/managed/server behaviour remains available when native portable detection returns false. Unknown native detection fails closed for all outbound prompts. Added source regression gates; full TypeScript/native build, Windows 10 screenshots and network monitoring are still pending. Legal/license panels are preserved. No changes to main and no Release.


### LISTADO 1: Windows executable publisher identity (staged; unverified)

Windows 10 Process Monitor Process Tree reported `Stirling PDF Inc.` as the PDF_Tunner.exe Company field. The portable Tauri JSON inherits upstream bundle publisher unless overridden; set `bundle.publisher` to `PDF_Tunner` only in the fork's portable Tauri config, while preserving upstream Cargo/legal attribution, and add a Windows executable CompanyName check rejecting any `Stirling` company identity. The final EXE metadata must still be verified by full Windows build and user VM. No change to upstream base/main or installer.
