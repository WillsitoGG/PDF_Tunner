# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**, extract and run without installation.
- `main` remains the clean pinned upstream base during v1 development.
- No final PDF_Tunner v1 Release exists yet.
- Latest complete green primary regression: **Run #119** (`37358156494`), job `111925742002`, commit `71a34bb065e419869cff96006ae9df06288d1f20`.
- **jbig2enc 0.32 is formally accepted by Run #108**, including exact source/tag, authenticated Meson inputs, static MSVC build, upstream tests, isolated package-first ToolProbe, relocation and a real OCRmyPDF `--optimize 2` result containing `/JBIG2Decode`.
- **RAR/CBR is formally accepted by Run #117**: deterministic real CBR→PDF, package-first optional encoder probe for PDF→CBR, explicit no-encoder failure, no bundled `rar.exe`, and the complete primary workflow including second-launch window restore all passed.
- Run #115 and #116 remain recorded below as failure history; #117 closed the RAR/CBR and HWND restoration gates, #118 reconfirmed the complete regression, and #119 accepted portable CFF PDF-JSON conversion.
- CI handoff incident: Run #117 completed successfully at 10:57 UTC, but its commit status stayed `pending` from 10:18 UTC because the status bridge only published at workflow start. Commit e48 adds terminal publication in an `always()` step and skips heavy CI for root README/AGENTS/RELEASE_STATUS-only changes. Run #118 attempt 1 hit an HTTPS timeout downloading pngquant from `pngquant.org`; the failed-job-only retry (attempt 2) completed green. The bridge published terminal `failure` for attempt 1 and `success` for attempt 2, confirming the repair.
- **CFF PDF-JSON conversion is formally accepted by Run #119**: the package-local converter, exact script provenance, real OpenType-CFF conversion and relocation all passed inside the complete primary workflow.
- Next: complete the exact pinned-source dependency parity audit, then representative functional E2E coverage and release-readiness checks against Stirling 2.14.3.

## Accepted portable layers

| Layer | Accepted identity / evidence |
| --- | --- |
| Native Tauri/JRE portable bootstrap | package-local backend/Tauri/WebView2/temp state and process containment; consolidated proof includes Run `32825188381` |
| Fixed WebView2 | `151.0.4129.101` x64; Run #62 `33058462619` |
| qpdf | `12.4.0` MinGW64; Run #66 `33086404875` |
| ImageMagick | `7.1.2-30` portable Q16 x64; Run #67 `33092698357` |
| Ghostscript | `10.07.1` Win64; Run #68 `33104114920` |
| Tesseract | release `5.5.3`, CLI `5.5.3.20260724`, pinned `eng`/`spa`/`osd`; Run #70 `33122172947` |
| Python + OCRmyPDF | Python `3.12.14` x64 + OCRmyPDF `17.10.0`; Run #77 `33201568275` |
| LibreOffice + UNO conversion | LibreOffice `26.2.5` + package-relative native `unoconvert.exe`; Run #83 `33497784837` |
| Poppler | `26.02.0` Windows x64; Run #86 `33507551477` |
| Python dependency lock | authenticated 28-package Windows lock; Run #87 and later complete regressions |
| NumPy | `2.5.2`; Run #90 `33530454097` |
| OpenCV | `opencv-python-headless 4.14.0.94`, runtime/core `4.14.0`, real `split_photos.py`; Run #92 `33557169326` |
| WeasyPrint | official Windows `69.0`, package-relative shim, real HTML→PDF + Markdown→PDF; Run #95 `33695530172` |
| Calibre | official Windows x64 `9.14.0`, package-relative `ebook-convert`; Run #96 `33748509811` |
| OCRmyPDF auxiliaries | unpaper `6.1` + pngquant `2.17.0`; Run #99 `33786563784` |
| Conversion fonts | LibreOffice MSI Latin baseline + pinned Noto Sans CJK `Sans2.004` Regular regional subsets; Run #103 `33896293861` |
| Embedded VeraPDF | `validation-model:1.30.2`; real PDF→PDF/A-2b→`verify-pdf`; Run #105 `33956010668` |
| **jbig2enc** | **`0.32`, tag→commit `309b2d55c7dfdcf0ab6afccb6d88834afc0bf2c0`; real OCRmyPDF optimize-2 `/JBIG2Decode`; Run #108 `34138754142`** |
| **RAR / CBR contract** | **CBR→PDF embedded `junrar`; optional package-first user RAR encoder for PDF→CBR; no bundled `rar.exe`; Run #117 `37295728617`** |
| **CFF PDF-JSON conversion** | **package-local Python + `cff/convert_cff_to_ttf.py`; real 2,221-glyph OpenType-CFF conversion + relocation; Run #119 `37358156494`** |

Pinned conversion-font hashes retained from the accepted Run #103 layer:

| Family | File | SHA-256 |
| --- | --- | --- |
| Noto Sans SC | `NotoSansSC-Regular.otf` | `faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9` |
| Noto Sans TC | `NotoSansTC-Regular.otf` | `5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537` |
| Noto Sans HK | `NotoSansHK-Regular.otf` | `8a43afea92bb58dfd9027bd7ac6f5b0b2662e2ffb3e7c1edc02c62b2b21924f1` |
| Noto Sans JP | `NotoSansJP-Regular.otf` | `dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073` |
| Noto Sans KR | `NotoSansKR-Regular.otf` | `69975a0ac8472717870aefeab0a4d52739308d90856b9955313b2ad5e0148d68` |

## Accepted milestone — embedded VeraPDF 1.30.2

VeraPDF is embedded in Stirling's Java application rather than shipped as a separate executable. The pinned core declares `org.verapdf:validation-model:1.30.2`, and the desktop JRE includes `jdk.dynalink`, which Stirling requires for VeraPDF runtime operation.

Run #104 (`33908989039`) reached the new E2E after the earlier primary gates but exposed a test-fixture problem: upstream `test_globalsign.pdf` was actually an HTML GlobalSign 404 page. The bounded diagnostics proved VeraPDF itself had initialized successfully. Commit `e2c2e0544bbd0f092980386b0e764550146c799e` replaced only that fixture dependency with a deterministic valid PDF while retaining the real PDF→PDF/A-2b→VeraPDF verification chain.

Run #105 attempt 1 then failed earlier at OCR auxiliary staging because `pngquant.org:443` timed out (`HttpRequestException` / socket `10060`). No code gate failed. A single rerun of the same job/commit succeeded completely. The live backend gate reported:

- `VeraPDF Greenfield initialized successfully`;
- PDF/A result `standard=PDF_A_2_B`, profile `2B`, `compliant=True`, `totalFailures=0`;
- `Verification complete for 1 standard(s) checked`.

Run #105 acceptance evidence:

- run `33956010668`, attempt `2`, job `101283384499`, commit `e2c2e0544bbd0f092980386b0e764550146c799e`;
- ZIP size `1,909,712,277` bytes;
- ZIP SHA-256 `5A3F30A60E014C12D5059C81A6DC7EC8789DB9F4D3D3F5DB1A4D1A7403CEC5FE`;
- portable layout `31,611` files / `4,387,634,583` payload bytes;
- lightweight evidence artifact `9967243279`, size `7,585` bytes, digest `sha256:cd87e3b3ebe282c47e06c018b4c6c602611bd372701d36fb321249e34586d24c`;
- the multi-gigabyte ZIP itself was not uploaded.

VeraPDF is closed/accepted; do not reopen it without new evidence.

## Accepted milestone — jbig2enc 0.32

OCRmyPDF `17.10.0` probes the literal executable name `jbig2`, and its Windows code explicitly warns that TeX Live may place an incompatible `jbig2.EXE` on host `PATH`. Optimize levels 2/3 recommend `jbig2enc >= 0.28`; this was a concrete parity/compression gap after Run #105.

The accepted implementation uses:

- upstream repository `agl/jbig2enc`;
- exact tag `0.32` → commit `309b2d55c7dfdcf0ab6afccb6d88834afc0bf2c0`;
- pinned Meson `1.10.0` wheel SHA-256 `4b27aafce281e652dcb437b28007457411245d975c48b5db3a797d3e93ae1585`;
- MSVC x64 release build with `b_vscrt=mt`, `default_library=static` and `--wrap-mode=forcefallback`;
- upstream authenticated Meson wrap hashes for Leptonica/codecs, with Meson's installed license closure retained;
- package path `tools/jbig2enc/`, ahead of inherited host `PATH` in portable mode.

The acceptance gate proves exact source/tag, authenticated dependency inputs, upstream Meson tests, AMD64 runtime identity, isolated `where.exe jbig2`, OCRmyPDF's exact `jbig2enc` ToolProbe, relocation to a path containing spaces, retained provenance/licenses and a real `ocrmypdf --optimize 2` result containing `/JBIG2Decode`.

### Runs #106–#108 closure

Run #106 (`33967722557`) reproduced the same step-30 boundary three times on commit `208b7c78e526f2ebd180f9fb80334db55d343ae9`. Bounded diagnostics exposed OCRmyPDF `--optimize 2` returning exit code `3`.

Commit `4b33063c721ea9eb58cddd955f8b306adb83a169` added phase-qualified observability. Run #107 (`34122536256`, job `101743654235`) isolated the failure as `PDF_TUNNER_JBIG2_PHASE_FAILED=runtime-e2e`: the source/build/tests/staging/ToolProbe path had passed, but the test-only isolated PATH hid already accepted `tools/bin/pngquant.exe`. OCRmyPDF 17.10.0 defines exit code `3` as `missing_dependency` and requires pngquant for optimize levels 2/3.

Commit `64f86ce6f567f49be1e677697221c52a8b26131f` made the minimal correction: require packaged `pngquant.exe` and include `tools/bin` in the jbig2enc runtime E2E PATH, matching the real portable bootstrap without weakening any source, provenance, relocation or `/JBIG2Decode` gate.

**Run #108 (`34138754142`, job `101795708391`) is completely green and formally accepts jbig2enc 0.32.** Evidence:

- commit `64f86ce6f567f49be1e677697221c52a8b26131f`;
- ZIP `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`;
- ZIP size `1,911,812,538` bytes;
- ZIP SHA-256 `9F4334CB90B79457D3515877308DC3A25E521132A3B5130E79ABA650CAE8C5CE`;
- portable layout `31,618` files / `4,392,280,088` payload bytes;
- lightweight evidence artifact `10026083402`, API size `7,583` bytes, digest `sha256:04170eabf8166d25b24d57977cbbd54edbe0501b94f4b13a59cbe0fd9708dbe4`;
- the multi-gigabyte ZIP itself was not uploaded.

jbig2enc is closed/accepted; do not reopen it without new evidence.

## Latest acceptance — CFF PDF-JSON conversion

Pinned Stirling 2.14.3 defaults CFF conversion to Linux-only paths (\`/opt/venv/bin/python3\` and \`/scripts/convert_cff_to_ttf.py\`). PDF_Tunner now maps only those upstream defaults, in portable mode, to bundled \`tools/python/python.exe\` and \`tools/python/cff/convert_cff_to_ttf.py\`; explicit custom settings remain untouched.

Run #119 (\`37358156494\`, job \`111925742002\`, commit \`71a34bb065e419869cff96006ae9df06288d1f20\`) passed the complete primary workflow. The package-local converter rebuilt a valid OpenType-CFF font with 2,221 glyphs, repeated successfully after relocation to a path containing spaces, and the final backend/package gates passed again. Evidence:

- converter script SHA-256 \`9d57d9ae721c97ff7581099c1dce55a1d3350b255f2b198055bf0e1c5bc3d15c\`;
- ZIP SHA-256 \`80821D577F7F4B8246AD69E95CDCCE9140D85ACA5AFE6EAB0ED3D60A2FCB1BE1\`;
- ZIP size \`1,911,877,412\` bytes;
- portable layout \`31,621\` files / \`4,392,452,052\` payload bytes;
- lightweight artifact \`11366833930\`, size \`7,758\` bytes, digest \`sha256:632172c024a509f811443ff48501be974d1bcfdaf60c1846198a903facf89eb6\`;
- the multi-gigabyte ZIP itself was not uploaded.

CFF PDF-JSON portability is closed/accepted; do not reopen it without new evidence.

## Accepted contract — RAR / CBR portability

Pinned Stirling 2.14.3 has asymmetric CBR behavior:

- **CBR→PDF** is implemented through embedded Java `junrar`, so that direction must work with no external `rar.exe`.
- **PDF→CBR** invokes the real RAR CLI exactly as `rar a -m5 -ep1 <output.cbr> <rendered PNG pages>`.
- A ZIP renamed to `.cbr` is not equivalent and is not an acceptable parity workaround.
- RAR/WinRAR redistribution terms do not provide a clean basis to bundle the standalone encoder inside PDF_Tunner without permission.

The v1 contract is therefore: CBR→PDF remains fully portable; PDF→CBR is available when the user supplies a legitimately licensed `rar.exe` in package-first `tools/rar/`; the distributed PDF_Tunner ZIP contains **no `rar.exe`**.

### Run #115 diagnosis and portable correction

Run #115 (`34218818659`, commit `f7e42a7c5bddebbb67ebc1050a54bd19f2bb6f80`) passed steps 1–34 and failed only in step 35, `Start PDF_Tunner and validate real backend`. Its bounded startup diagnostics showed `Missing dependency: rar`: upstream `ExternalAppDepConfig` performs dependency discovery once during startup and permanently disables the RAR group when `rar` is absent. That conflicts with PDF_Tunner's deliberate optional-user-supplied encoder path because adding `tools/rar/rar.exe` later cannot reactivate the route. Separately, reproducing the deterministic 146-byte RAR3 fixture proved that the scripted bytes hash to `f3d3e772d72fc274146f45eaf8c37b97dad35f5add83b22c0d1e7c5c603373d0`, not the previously documented `136cda2e...` value.

PDF_Tunner therefore makes one narrow runtime adaptation: **RAR alone is a lazy optional dependency**. If `rar` is absent at startup, the RAR endpoint group stays enabled rather than being permanently disabled; the actual `rar` command is still resolved normally from the package-first `PATH` when PDF→CBR is invoked. This lets a user drop a legitimate encoder into `tools/rar/` before or after launch. If no encoder is present when conversion is attempted, the real route fails explicitly. Every other external dependency keeps Stirling's existing startup-disable behavior.

The active CI gate uses `.github/scripts/validate-rar-cbr.ps1` plus a CI-only native probe:

1. build a deterministic 146-byte real RAR3/CBR fixture in-memory, containing a valid 2×2 PNG and pinned by SHA-256 `f3d3e772d72fc274146f45eaf8c37b97dad35f5add83b22c0d1e7c5c603373d0`;
2. prove backend startup did **not** disable the RAR group even though no `rar.exe` is present;
3. call the real `/api/v1/convert/cbr/pdf` endpoint with **no `rar.exe` present**, then validate the output using packaged qpdf;
4. after the backend is already running, temporarily place a CI-only `rar.exe` probe under `tools/rar/` and prove the real `/api/v1/convert/pdf/cbr` route dynamically resolves that package copy and passes exactly `a -m5 -ep1`, a `.cbr` output and rendered PNG inputs;
5. the probe deliberately emits `PDF_TUNNER_RAR_PROBE_ONLY` rather than a RAR archive, so it cannot be mistaken for an encoder or product functionality;
6. remove the probe and prove PDF→CBR fails explicitly when no encoder exists, with no ZIP-as-CBR fallback;
7. scan the portable tree and fail if any `rar.exe` remains.

RAR/CBR is **closed/accepted by Run #117**: the corrected contract passed inside the complete primary regression, including real CBR→PDF, package-first optional PDF→CBR encoder resolution, explicit no-encoder failure, no bundled `rar.exe` and second-launch window restoration.

## Portable architecture

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside the executable.

Key package-relative paths:

- backend config/logs/working state → `data/`;
- Java temp → `data/tmp/`;
- WebView2 profile → `data/webview2/`;
- Tauri logs/store/cookies/window state → `data/tauri/...`;
- ImageMagick → `tools/imagemagick/`;
- Ghostscript → `tools/ghostscript/bin/`;
- Tesseract → `tools/tesseract/`, models → `tools/tesseract/tessdata/`;
- Python/OCRmyPDF/NumPy/OpenCV → `tools/python/`; the CFF font converter → `tools/python/cff/convert_cff_to_ttf.py`;
- LibreOffice → `tools/libreoffice/`; `unoconvert.exe` → `tools/bin/`;
- conversion fonts → `tools/libreoffice/share/fonts/truetype/`; provenance → `tools/fonts/`;
- Poppler → `tools/poppler/Library/bin/`;
- WeasyPrint → `tools/weasyprint/`; shim → `tools/bin/weasyprint.exe`;
- Calibre → `tools/calibre/`; launcher → `tools/bin/ebook-convert.exe`;
- OCRmyPDF auxiliaries → `tools/bin/unpaper.exe`, sibling DLLs and `tools/bin/pngquant.exe`;
- jbig2enc → `tools/jbig2enc/jbig2.exe`;
- optional licensed RAR encoder path → `tools/rar/`.

Portable mode skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## Validation and CI policy

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency or functional layer is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. Version output alone is never sufficient: validate source/hash or embedded identity, package-first isolation, real operation, relocation where practical, backend behavior where applicable, state/process containment and the final assembled package.

Heavy CI uses branch-scoped concurrency with `cancel-in-progress: true`. Do not launch redundant complete regressions. Ordinary CI builds and validates the portable ZIP but uploads only lightweight evidence; the multi-gigabyte ZIP itself is reserved for the final Release after all v1 gates and explicit user authorization.

## Remaining v1 roadmap

### A. External toolchain / embedded runtime parity

1. **RAR/CBR portability contract** — accepted by Run #117;
2. **CFF PDF-JSON font conversion** — accepted by Run #119;
3. finish exact dependency audit against pinned Stirling 2.14.3 and close any remaining concrete gap.

The upstream PDF-to-video controller and external FFmpeg probe are disabled in pinned Stirling 2.14.3; do not add FFmpeg to the portable bundle unless that feature is deliberately re-enabled and security-reviewed.

### B. Representative functional E2E

Cover OCR, Office↔PDF, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, VeraPDF, jbig2enc, RAR/CBR behavior and representative Stirling API families. Tests must prove runner-installed software is not satisfying package gates.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove retired diagnostic/focused mechanisms;
5. downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish the clean v1 ZIP only after all gates and explicit user authorization;
9. execute the manual clean-machine Windows 10/11 checklist.

## Compact handoff

- Latest complete green primary: **Run #119** (\`37358156494\`), job \`111925742002\`, commit \`71a34bb065e419869cff96006ae9df06288d1f20\`.
- Run #119 ZIP SHA-256 \`80821D577F7F4B8246AD69E95CDCCE9140D85ACA5AFE6EAB0ED3D60A2FCB1BE1\`; size \`1,911,877,412\` bytes; layout \`31,621\` files / \`4,392,452,052\` bytes; lightweight artifact \`11366833930\`, size \`7,758\`, digest \`sha256:632172c024a509f811443ff48501be974d1bcfdaf60c1846198a903facf89eb6\`.
- **CFF PDF-JSON conversion** is accepted by Run #119; **RAR/CBR** remains accepted by Run #117; **jbig2enc 0.32** remains accepted by Run #108.
- Run #119 reconfirmed the complete backend, dependency, relocation, packaging and second-launch window-state regression with every earlier accepted gate enabled.
- Next: exact pinned-source dependency parity audit, followed by representative E2E and final branding/portability/cleanup/release-readiness audits.
- Long-run protocol: track exact Actions run ID/attempt, use terminal Actions conclusion as primary evidence, keep concise progress updates flowing, and continue independent audits while CI runs.
- No final Release has been published.
