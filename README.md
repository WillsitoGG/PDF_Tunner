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
- Latest complete green primary regression: **Run #129** (`37754829944`), job `113236699098`, commit `804cd9950f71a6aaa4db9572ca2276e8080958aa`; full ZIP retained temporarily for clean-machine manual testing.
- **jbig2enc 0.32 is formally accepted by Run #108**, including exact source/tag, authenticated Meson inputs, static MSVC build, upstream tests, isolated package-first ToolProbe, relocation and a real OCRmyPDF `--optimize 2` result containing `/JBIG2Decode`.
- **RAR/CBR is formally accepted by Run #117**: deterministic real CBR→PDF, package-first optional encoder probe for PDF→CBR, explicit no-encoder failure, no bundled `rar.exe`, and the complete primary workflow including second-launch window restore all passed.
- Run #115 and #116 remain recorded below as failure history; #117 closed the RAR/CBR and HWND restoration gates, #118 reconfirmed the complete regression, and #119 accepted portable CFF PDF-JSON conversion.
- CI handoff incident: Run #117 completed successfully at 10:57 UTC, but its commit status stayed `pending` from 10:18 UTC because the status bridge only published at workflow start. Commit e48 adds terminal publication in an `always()` step and skips heavy CI for root README/AGENTS/RELEASE_STATUS-only changes. Run #118 attempt 1 hit an HTTPS timeout downloading pngquant from `pngquant.org`; the failed-job-only retry (attempt 2) completed green. The bridge published terminal `failure` for attempt 1 and `success` for attempt 2, confirming the repair.
- **CFF PDF-JSON conversion is formally accepted by Run #119**: the package-local converter, exact script provenance, real OpenType-CFF conversion and relocation all passed inside the complete primary workflow.
- **Tesseract upstream language parity is formally accepted by Run #123**: package-local `eng`, `spa`, `deu`, `fra`, `por`, `chi_sim`, `osd`, exact `tessdata_fast` blob pins, real isolated load/execute probes and live-backend acceptance all passed. The current exact external/embedded dependency audit found no further concrete code-backed gap, and subsequent Runs #124–#128 accepted representative EML/Office/table E2E and complete branding/cleanup. Current gate: clean-machine manual validation and explicit release authorization, as detailed in `RELEASE_STATUS.md`.

## Accepted portable layers

| Layer | Accepted identity / evidence |
| --- | --- |
| Native Tauri/JRE portable bootstrap | package-local backend/Tauri/WebView2/temp state and process containment; consolidated proof includes Run `32825188381` |
| Fixed WebView2 | `151.0.4129.101` x64; Run #62 `33058462619` |
| qpdf | `12.4.0` MinGW64; Run #66 `33086404875` |
| ImageMagick | `7.1.2-30` portable Q16 x64; Run #67 `33092698357` |
| Ghostscript | `10.07.1` Win64; Run #68 `33104114920` |
| Tesseract | release `5.5.3`, CLI `5.5.3.20260724`, pinned `eng`/`spa`/`deu`/`fra`/`por`/`chi_sim`/`osd`; upstream language parity Run #123 `37490571449` |
| Python + OCRmyPDF | Python `3.12.14` x64 + OCRmyPDF `17.10.0`; Run #77 `33201568275` |
| LibreOffice + UNO conversion | LibreOffice `26.2.5` + package-relative native `unoconvert.exe`; Run #83 `33497784837` |
| Poppler | `26.02.0` Windows x64; Run #86 `33507551477` |
| Python dependency lock | authenticated 29-package Windows lock including `pdf2image 1.17.0`; Run #120 `37459765068` |
| NumPy | `2.5.2`; Run #90 `33530454097` |
| OpenCV | `opencv-python-headless 4.14.0.94`, runtime/core `4.14.0`, real `split_photos.py`; Run #92 `33557169326` |
| WeasyPrint | official Windows `69.0`, package-relative shim, real HTML→PDF + Markdown→PDF + EML→PDF; EML acceptance Run #124 attempt 2 `37496831786` |
| Calibre | official Windows x64 `9.14.0`, package-relative `ebook-convert`; Run #96 `33748509811` |
| OCRmyPDF auxiliaries | unpaper `6.1` + pngquant `2.17.0`; Run #99 `33786563784` |
| Conversion fonts | LibreOffice MSI Latin baseline + pinned Noto Sans CJK `Sans2.004` Regular regional subsets; Run #103 `33896293861` |
| Embedded VeraPDF | `validation-model:1.30.2`; real PDF→PDF/A-2b→`verify-pdf`; Run #105 `33956010668` |
| **jbig2enc** | **`0.32`, tag→commit `309b2d55c7dfdcf0ab6afccb6d88834afc0bf2c0`; real OCRmyPDF optimize-2 `/JBIG2Decode`; Run #108 `34138754142`** |
| **RAR / CBR contract** | **CBR→PDF embedded `junrar`; optional package-first user RAR encoder for PDF→CBR; no bundled `rar.exe`; Run #117 `37295728617`** |
| **CFF PDF-JSON conversion** | **package-local Python + `cff/convert_cff_to_ttf.py`; real 2,221-glyph OpenType-CFF conversion + relocation; Run #119 `37358156494`** |
| **PDF→WebP Python/Poppler parity** | **`pdf2image 1.17.0` + package-local Poppler `pdfinfo`/`pdftoppm`; real `png_to_webp.py` E2E + relocation; Run #120 `37459765068`** |
| **Secure CFF→TTF reconstruction** | **fontTools `4.64.0` Cu2QuPen; real 2,221-glyph TrueType output with `glyf`/`loca`, no `CFF ` table, relocation; Run #122 `37472331284`** |

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

## Latest acceptance — secure CFF→TTF reconstruction

The parity audit found that PDF reconstruction could still call Stirling's FontForge fallback whenever the Python CFF converter produced OpenType-CFF rather than TrueType. PDF_Tunner now closes that path without bundling FontForge: the package-local converter uses the already authenticated fontTools `4.64.0` Cu2QuPen implementation to rebuild real TrueType outlines.

Run #121 (`37471270073`, commit `73e07e12cf647f4a14c50d7194936c8063b3eff0`) exercised the new gate but exposed a test-only binary-signature escaping error. Commit `b5947844ea8a4525626dba96099105c2730a4085` corrected only that gate. **Run #122** (`37472331284`, job `112299193532`) then passed the complete primary workflow with every earlier gate enabled. Acceptance evidence:

- package-local CFF converter SHA-256 `fb8b7f3d2911512f32760b50ccb593b7f26838c87d9cf9d53b4d3414e6783a85`;
- real conversion produced a valid TrueType font with exactly `2,221` glyphs and no FontForge requirement;
- the same gate passed after relocation and during the live-backend regression;
- ZIP SHA-256 `20DAAAD8F7CA3D1F1FC41FE3D6197A68DB36F8DF5CBB0D462BFE8CB0C5545953`;
- ZIP size `1,911,909,447` bytes;
- portable layout `31,639` files / `4,392,527,297` payload bytes;
- lightweight evidence artifact `11420435593`, size `7,857` bytes, digest `sha256:93f604924c3ed619936e50c65daac66abffdbc49f21efa213dba8951fffd5400`;
- the multi-gigabyte ZIP itself was not uploaded.

Secure CFF→TTF reconstruction is closed/accepted; do not reopen it without new evidence.

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
3. **PDF→WebP Python/Poppler parity** — accepted by Run #120;
4. **Secure CFF→TTF reconstruction** — accepted by Run #122 using authenticated fontTools 4.64.0 Cu2QuPen, so portable PDF reconstruction no longer needs the FontForge fallback;
5. **Tesseract upstream language parity** — accepted by Run #123 with pinned `deu`, `fra`, `por`, `chi_sim` plus existing `eng`, `spa`, `osd`, exact blob provenance and isolated/runtime-backend probes;
6. the current exact pinned-source pass found no further concrete external/embedded dependency gap; reopen only if later code review produces new evidence.

PDF_Tunner deliberately does **not** bundle the current official Windows FontForge 20251009 build for this fallback. That release is affected by multiple 2025 memory-safety advisories, including NVD CVE-2025-15279; feeding embedded fonts from untrusted PDFs into that parser would introduce an avoidable attack surface. Explicit upstream/custom FontForge configuration remains supported, but the portable default must not depend on it.

The upstream PDF-to-video controller and external FFmpeg probe are disabled in pinned Stirling 2.14.3; do not add FFmpeg to the portable bundle unless that feature is deliberately re-enabled and security-reviewed.

### B. Representative functional E2E

Cover OCR, Office↔PDF, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, VeraPDF, jbig2enc, RAR/CBR behavior and representative Stirling API families. Tests must prove runner-installed software is not satisfying package gates. **EML→PDF is accepted by Run #124 attempt 2** using Stirling's pinned `sample.eml`, packaged WeasyPrint and packaged Poppler `pdftotext` content verification. **PDF→PPTX is accepted by Run #125**, extending the existing Office→PDF + PDF→DOCX backend contract through `/api/v1/convert/pdf/presentation` with coherent OOXML. **PDF→CSV/XLSX is accepted by Run #126** using pinned `testing/cucumber/exampleFiles/tables.pdf`: `/api/v1/convert/pdf/csv` returned exactly three non-empty CSV files and `/api/v1/convert/pdf/xlsx` returned a coherent OOXML workbook with worksheet payload. URL→PDF remains disabled by default in pinned Stirling 2.14.3 because upstream marks it INTERNAL ONLY with known security issues; do not enable it merely for CI coverage.

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

- **Latest complete green primary and downloadable manual-test candidate: Run #129** (`37754829944`, job `113236699098`, commit `804cd9950f71a6aaa4db9572ca2276e8080958aa`). All primary checks passed, including the opt-in full-ZIP upload.
- Actual application ZIP `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`: **SHA-256 `5ABDEE66382A04BE063CD19BB7C8A40C844CB143A778E048D78D9891433EF95C`**; size `1,916,065,686` bytes; `31,643` files / `4,399,867,226` uncompressed bytes. The SHA of the produced ZIP equals the uploaded artifact digest because this candidate uses `archive: false`.
- **Download the temporary actual ZIP:** [Run #129 artifact #11541921231](https://github.com/WillsitoGG/PDF_Tunner/actions/runs/37754829944/artifacts/11541921231). GitHub reports expiry **2026-10-09 09:53:21 UTC (11:53:21 Europe/Madrid)**; save a local copy before expiry. The ZIP is for Windows manual acceptance and is **not a published Release**.
- Lightweight evidence artifact `11541945715`: size `7,855` bytes; digest `sha256:2d133a638c83e24a9c18c968b375d6c76798fa6dc51d4849793c0e13ce085266`. The evidence itself confirms the same Run ID/attempt, commit, ZIP size/SHA and uncompressed layout.
- Run #128 formally accepted complete branding, E2E, portability and retired-workflow cleanup; #129 reconfirms all existing gates with **no product-code changes** and proves full candidate upload.
- **Active gate:** the user must download, SHA-verify and execute real Windows 10/11 clean-machine tests. See [`RELEASE_STATUS.md`](RELEASE_STATUS.md). No additional automated heavy run, `main` integration or final GitHub Release is authorized solely by the successful CI result.
- Long-run protocol: capture a heavy Run ID once then stop polling; the user reports terminal status. No unnecessary CI executions.


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
