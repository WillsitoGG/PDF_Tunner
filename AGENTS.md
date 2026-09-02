# AGENTS.md

Permanent technical context and operating contract for **PDF_Tunner**. Read this file before changing the repository.

## Identity, base and target

PDF_Tunner is the real fork `WillsitoGG/PDF_Tunner` of `Stirling-Tools/Stirling-PDF`, not a wrapper repository.

- Pinned upstream version: `2.14.3`
- Pinned upstream commit: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: Windows 10/11 x64 portable ZIP, extract and run.
- Preserve Stirling non-Enterprise functionality unless explicitly removed.
- Bundle required runtimes/dependencies whenever technically viable.
- Keep runtime config/cache/log/temp/state inside the portable tree as far as underlying Windows APIs permit.
- Keep the downstream delta small and easy to rebase on Stirling upstream.
- No final PDF_Tunner v1 Release exists yet; `main` remains the clean upstream base while v1 is developed.

## Mandatory repository rules

1. Preserve Stirling's root structure; do not reorganize the fork into generic archive/source roots.
2. Keep `main` clean: no generated builds, logs, abandoned experiments, one-shot triggers or temporary scripts.
3. Preserve upstream behavior unless the user requests removal or functionality is outside target.
4. Compilation alone is never validation. Validate the assembled portable app and real operations.
5. Never archive failed/intermediate builds as release history.
6. Keep SHA-256/provenance and exact dependency identity reproducible.
7. **Every PDF_Tunner-specific change must update BOTH `README.md` and `AGENTS.md` in the same final commit.**
8. Heavy CI must use branch/workflow-specific concurrency with `cancel-in-progress: true`.
9. Use at most one automatic trigger per heavy workflow unless technically necessary.
10. Remove development-only focused workflows/triggers when their phase is complete and before final `main`.
11. Do not reopen old PR #1 as the v1 release integration vehicle.
12. Do not publish a final Release until toolchain, E2E, parity, branding, portability, cleanup and documentation gates are complete.

## Continuity protocol

Before writes in a resumed conversation:

1. recover the most recent PDF_Tunner handoff;
2. read current project rules, README and AGENTS;
3. verify live branch HEAD, latest primary Actions run, PR state and Release state;
4. carry accepted/closed, active candidate, next block and broader roadmap explicitly;
5. never treat one immediate task as the only remaining work;
6. at each accepted milestone record commit, Run/job, artifact/digest where relevant, next candidate and remaining roadmap in README + AGENTS;
7. before final Release re-audit against the full original PDF_Tunner objective.

## Architecture and portable boundary

Use Stirling's own Tauri desktop under `frontend/editor/src-tauri`. Do not restore the old `PDF_Tunner_Legacy` .NET/WebView2 launcher architecture.

Portable mode is enabled by `PDF_TUNNER_PORTABLE` beside the executable.

Do **not** globally replace `APPDATA`, `LOCALAPPDATA`, `PROGRAMDATA`, `USERPROFILE`, `HOME`, `TEMP` or `TMP` before Tauri/WebView2 initializes. Use component-specific localization:

- `PDF_TUNNER_PORTABLE_ROOT` -> executable directory;
- Stirling app data -> `<portable>/data`;
- Java temp -> `<portable>/data/tmp` through `JAVA_TOOL_OPTIONS`;
- WebView2 user data -> `<portable>/data/webview2`;
- Tauri logs/store/window-state/http cookies -> `<portable>/data/tauri/...`;
- ImageMagick config -> `<portable>/tools/imagemagick`, temp -> `<portable>/data/tmp/imagemagick`;
- Ghostscript -> package-first `<portable>/tools/ghostscript/bin`;
- Tesseract -> package-first `<portable>/tools/tesseract`, `TESSDATA_PREFIX=<portable>/tools/tesseract/tessdata`;
- Python/OCRmyPDF -> `<portable>/tools/python`; OCRmyPDF child temp -> `<portable>/data/tmp/ocrmypdf`; Python cache -> `<portable>/data/python-cache`;
- LibreOffice -> `<portable>/tools/libreoffice`; native source-compatible `unoconvert.exe` -> `<portable>/tools/bin`; LibreOffice child temp -> `<portable>/data/tmp/libreoffice`; transient per-invocation shim profiles -> `<portable>/p/` and must be empty after each conversion;
- Poppler -> `<portable>/tools/poppler`, executables under `Library/bin`;
- WeasyPrint official Windows payload -> `<portable>/tools/weasyprint`; package-relative command shim -> `<portable>/tools/bin/weasyprint.exe`; per-invocation PyInstaller/temp state -> `<portable>/data/tmp/weasyprint` and must be removed after each invocation;
- Calibre config -> `<portable>/data/calibre` when packaged;
- skip `pdf-tunner://` deep-link registration in portable mode.

## External dependency source of truth

For Stirling 2.14.3 inspect at least:

- `app/core/src/main/java/stirling/software/SPDF/config/ExternalAppDepConfig.java`;
- `app/common/src/main/java/stirling/software/common/configuration/RuntimePathConfig.java`;
- `docker/base/Dockerfile`;
- controllers/services executing each feature.

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

Also audit Poppler `pdfinfo`/`pdfimages`, `unpaper`, `pngquant`, NumPy/OpenCV, WeasyPrint, LibreOffice/UNO, Calibre, conversion fonts, VeraPDF E2E, `jbig2enc` and any additional exact dependency exposed by pinned source.

## Tool layout strategy

Package under one `tools/` subtree per dependency. Tauri prepends, when present:

- `tools/bin`;
- `tools/python` and `tools/python/Scripts`;
- `tools/libreoffice/program`;
- `tools/tesseract`;
- `tools/ghostscript/bin`;
- `tools/qpdf/bin`;
- `tools/poppler/Library/bin`;
- `tools/weasyprint` stores the official backend executable, while the literal command is provided from `tools/bin`;
- `tools/imagemagick`;
- `tools/calibre`;
- `tools/pngquant`;
- `tools/unpaper`;
- `tools/rar`;
- `tools/jbig2enc`.

If Windows executable naming differs from Stirling's literal probe, provide a deterministic package-local alias/shim only after proving the exact probe. Never count runner-installed software as package evidence.

## Accepted layers and evidence

### Native portable/Tauri containment — accepted

Real packaged startup/backend health, Java temp localization, WebView2 profile localization, package-local Tauri stores/logs/http cookies, protocol containment, normal process-tree cleanup and two-launch window-state persistence are accepted. Run `32825188381` is the key consolidated AppData/window-state proof.

### Fixed WebView2 — accepted

- `151.0.4129.101` x64;
- official CAB SHA-256 `c386640d35f7a4604d088925a9bb01938400297f6da6fe985b72614daba87cda`;
- acceptance Run `33058462619` (#62), job `98471041328`, commit `72924f81d1b54afe06563c9636b26f1cf1e4aca4`.

### qpdf — accepted

- `12.4.0` MinGW64;
- SHA-256 `dcec940ce825b3b654d4936918190f52e7bfca85b7fb1c49bc24b3035185b4f5`;
- acceptance Run `33086404875` (#66), job `98567113737`, commit `413994c9ea368b5144a26686afef6011eba8de59`.

### ImageMagick — accepted

- `7.1.2-30` portable Q16 x64;
- SHA-256 `47a4ffd20f9360fc85817286df29019fad781df15002dcffdd260c9b27a9e4d8`;
- acceptance Run `33092698357` (#67), job `98589465377`, commit `d1801e8569a23a762035a39dc7295de0f19e6115`.

### Ghostscript — accepted

- `10.07.1` Win64;
- SHA-256 `3a4c28d0aac47aa7cccd35a5932c55110376e9dbd966898dde388b7faba444a4`;
- acceptance Run `33104114920` (#68), job `98629258424`, commit `84b2fb4a8dd1e69896abc7147442aabec68c3004`.

### Tesseract — accepted

- release `5.5.3`, Windows CLI `5.5.3.20260724`;
- installer SHA-256 `bee9e3434bd94fd65387d9be28cd467a41f61b1275383b55b0f59a1331270ae4`;
- `tessdata_fast` commit `87416418657359cb625c412a48b6e1d6d41c29bd`;
- acceptance Run `33122172947` (#70), job `98691480028`, commit `52429eb7812e8615ee39aab695641d495798c1ba`; artifact `9667429758`, digest `sha256:12943b1b38ac7660156667acbaf5a0d3ccae189d0f9d28be97fe32b0db8326aa`.

### Python 3.12.14 + OCRmyPDF 17.10.0 — accepted

Pins:

- Python `3.12.14` x64 from `astral-sh/python-build-standalone` release `20260825`;
- archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` PyPI wheel;
- wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

`.github/scripts/ocrmypdf-launcher.rs` builds a native relative launcher under `tools/python/ocrmypdf.exe`, executing sibling `python.exe -m ocrmypdf` and localizing OCRmyPDF temp/Python cache to `data/`.

Primary acceptance: Run **`33201568275` (#77)**, job **`98952028665`**, commit **`54802c15427673c0e95738195947ab76239d6e31`**, complete success with all earlier gates enabled.

Run #77 proved exact pins/hashes, AMD64 Python, isolated package-only resolution, clean `pip check`, real searchable-PDF OCR, searchable-text extraction, package-local temp/cache, relocation to a path containing spaces, real backend acceptance of `ocrmypdf`, final layout validation, ZIP creation and SHA-256.

Artifact **`9698621272`**, name `PDF_Tunner-Windows-x64-Portable-bootstrap`, Actions digest **`sha256:68f69bb0d4ed6b731aefee82abff3eba7b01d18c5b270051e2e546337cd6a164`**. CI evidence only; not a final Release.

The temporary focused OCRmyPDF workflow is retired after this primary acceptance; the permanent prepare/validate/launcher scripts remain part of the primary workflow.

### Portable Python dependency lock — accepted

Do not return to unconstrained `pip install` dependency resolution. Run #87 accepted the 27-package baseline of `.github/config/ocrmypdf-py312-windows-x64.lock.txt`, SHA-256 `d58c07e22837967fbbefb1f9f5168c100bfe47535c88445ccbad156f7fcd1374`, with one authenticated CPython 3.12 Windows x64/universal wheel hash per exact requirement.

`.github/scripts/prepare-ocrmypdf.ps1` must verify the repository lock hash and OCRmyPDF pin, download exactly the locked wheelhouse with `--require-hashes`, reject unknown/count-mismatched wheels, and install offline from that wheelhouse with no dependency resolution. It packages the lock as `tools/python/DEPENDENCY_LOCK.txt`, emits deterministic `DEPENDENCIES.txt`, records lock hash/count in provenance, and rejects any installed non-bootstrap package outside the lock. `.github/scripts/validate-ocrmypdf.ps1` must independently recheck source/packaged lock hashes, exact inventory and live installed versions before preserving all existing OCR, searchable-text, isolation and relocation gates. The lightweight artifact may retain the small Python provenance, lock and inventory files; it must never retain the wheelhouse.

Complete primary Run #87 (`33521994024`), job `99903300606`, commit `b18ff6d5b6cc1ebc22a142f970e5d221f66485ed`, passed every earlier gate plus exact lock/hash checks, authenticated download of all 27 wheels, offline installation, rejection of packages outside the lock, repeated clean `pip check`, real OCR/searchable-text validation and relocation with spaces. The generated ZIP was `1,463,925,596` bytes, SHA-256 `9F1BA2BCF2452C47D864ECE91AB4FBA876D4567502A1D398C6DE69A77C704E5C`, and was not uploaded. Artifact `9807333187`, `PDF_Tunner-Windows-x64-CI-evidence`, is `4,545` bytes with Actions digest `sha256:33151eacdedd60fafe84e34fbeeb947716b651d35aee7dac0704dee172ea68cd`, expires 2026-09-08, and contains eight lightweight files including Python provenance, exact lock and inventory. Its layout summary records 28,579 files / 3,367,817,902 payload bytes. The portable Python dependency lock is formally accepted.

### NumPy 2.5.2 — accepted

The accepted lock now contains 28 packages. It pins NumPy `2.5.2` to the CPython 3.12 Windows AMD64 wheel SHA-256 `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`; the complete lock SHA-256 is `ededb999049d81b85527f4d4aa679179e747669df300083d91bc2dd4e14e430f`. Pinned Stirling source imports NumPy in `app/core/src/main/resources/static/python/split_photos.py` together with `cv2`; there is no standalone Java NumPy probe, so this block establishes the compiled numerical base used by OpenCV.

Keep every accepted lock/OCR gate. In addition, preparation must verify the exact NumPy lock entry and wheel hash and record them in package provenance. Validation must prove the exact live version; package-local resolution of `numpy` and `_multiarray_umath`; AMD64 PE identity for the compiled core and every packaged `numpy.libs` DLL; deterministic matrix multiplication; and the same checks after relocation with spaces. The wheelhouse and ZIP remain prohibited as ordinary artifacts. Formal acceptance requires one complete primary regression with all earlier gates enabled.

Primary Run #88 (`33528451159`), job `99925173576`, commit `b02b7f89a38f370c2102e4aea61aabe9e259ef67`, failed before every functional gate because the auxiliary connector-status bridge replayed historical statuses until GitHub forcibly closed the transport connection. The subsequent bounded diagnostic artifact upload also timed out; no artifact exists and no portable ZIP was built. This is infrastructure failure, not NumPy evidence. The bridge must publish at most the current run and latest completed predecessor, with short timeouts/retries and a two-minute workflow bound; it is best-effort and must never weaken or block functional gates.

Corrective primary Run #89 (`33529648123`), job `99929237590`, commit `92edd653e62cdd6d6e04f59889eac2c90e1b9ed9`, failed in the PowerShell preflight before every functional gate because the bridge warning string contained the parser-invalid interpolation `$RunId:`. No ZIP or payload was built. Its only retained output is text-only diagnostic artifact `9809195211`, `PDF_Tunner-startup-diagnostics`, at `1,309` bytes with digest `sha256:8e89549f40c874137c13db9a741f48d5eb16607a851e7f8aa21fad2a4fb0e792`, expiring 2026-09-04. Use `${RunId}:` so the colon is outside the variable name. This run did not count as NumPy acceptance evidence.

Complete primary Run #90 (`33530454097`), job `99931980241`, commit `c32fb84eb2c0f7b157ef3217c59e57eee20b895b`, passed all earlier gates plus the exact 28-package lock/inventory, package-local NumPy module and compiled core, AMD64 core/DLL identity, deterministic matrix multiplication and repeated relocation with spaces. The generated ZIP was `1,480,791,164` bytes with SHA-256 `B1E7FB8E38DA90992FCBDC63118B7E8BEDE644EA434693AA2F1062B38709F473` and was not uploaded. Artifact `9810633011`, `PDF_Tunner-Windows-x64-CI-evidence`, is `4,727` bytes with Actions digest `sha256:d47a3e77de6788a32a6b9287452d53507b7c6ab04ba5e5aad15b259f4b72d0f9`, expires 2026-09-08, and contains exactly eight lightweight evidence files; its layout summary records 29,936 files / 3,421,683,208 payload bytes. NumPy 2.5.2 is formally accepted.

### OpenCV 4.14.0.94 — accepted

Source-backed scope: pinned Stirling `app/core/src/main/resources/static/python/split_photos.py` imports `cv2` + NumPy and uses OpenCV thresholding, dilation, contour detection, auto-rotation and image output. `ExternalAppDepConfig` independently probes the `OpenCV` group through Python `import cv2`.

Accepted distribution: **`opencv-python-headless 4.14.0.94`**, because the pinned Stirling usage requires image-processing APIs but no OpenCV GUI functions. Exact Windows x64 wheel: `opencv_python_headless-4.14.0.94-cp37-abi3-win_amd64.whl`; SHA-256 `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`. PyPI declares `numpy>=2` for Python >=3.9, satisfied by accepted NumPy `2.5.2`.

Do **not** rewrite the accepted 28-package OCRmyPDF/NumPy lock for this block. OpenCV uses dedicated repository lock `.github/config/opencv-py312-windows-x64.lock.txt`, SHA-256 `ec341586a884015445d4e28debbdd00b57ac903a36405bc7e0b9020e12dfd6c6`. `.github/scripts/prepare-ocrmypdf.ps1` keeps the accepted base wheelhouse unchanged, then downloads exactly this one OpenCV wheel with `--require-hashes`, validates exact filename/platform/hash, installs offline, records `OPENCV_*` provenance and emits a combined exact installed inventory. Neither wheelhouse nor wheel may become an Actions artifact.

`.github/scripts/validate-ocrmypdf.ps1` preserves every prior Python/OCRmyPDF/NumPy gate and additionally verifies: source/packaged OpenCV lock identity; exact PyPI distribution version `4.14.0.94`; exact runtime/core version `4.14.0` from `cv2.__version__`; package-local `cv2` resolution; all packaged OpenCV `.pyd`/DLL binaries are AMD64; actual pinned Stirling `split_photos.py` processes a generated two-photo fixture and yields exactly two valid crops; the same proof succeeds after relocation to a path containing spaces; and live backend logs contain neither `Missing dependency: Python with OpenCV` nor `Disabling group: OpenCV`. Never compare the four-component `opencv-python-headless` distribution version directly with `cv2.__version__`; the wheel build component is not part of the OpenCV runtime version.

Primary Run #91 (`33539166188`), job `99960820047`, commit `92643f78737dc64e851156d23050a61927ba60bf`, authenticated and installed the correct candidate but exposed a validator-only version-semantic failure (`4.14.0.94` distribution vs `cv2.__version__=4.14.0`). Corrective commit `c4c2b7f6e320840faf3d8c61967351b529875a50` split those identities without changing payload, lock, hash or functional gates.

Complete primary Run #92 (`33557169326`), job `100020722841`, commit `c4c2b7f6e320840faf3d8c61967351b529875a50`, passed every previously accepted gate plus corrected distribution/runtime checks, package-local AMD64 OpenCV native validation, real pinned Stirling `split_photos.py` E2E yielding exactly two valid crops, repeated relocation with spaces, OCR/NumPy regressions, real backend acceptance, state/process cleanup, final layout validation and ZIP generation. The generated ZIP was `1,523,242,671` bytes with SHA-256 `B179CC0CDC50C9BD9A4171F987535979A2380C26519927E753D015F69CF8A23B` and was not uploaded. Artifact `9820918487`, `PDF_Tunner-Windows-x64-CI-evidence`, is `4,890` bytes with Actions digest `sha256:7c7145e3aed4514ec91328da4393fe0f7626ac7ddfd259fad84461c8eb51a39a`, expires 2026-09-08, and contains exactly eight lightweight evidence files. Its layout summary records `30,042` files / `3,537,776,401` payload bytes. **OpenCV is formally accepted. WeasyPrint is the active external-toolchain block.**

### WeasyPrint 69.0 — active candidate

Source-backed scope: `RuntimePathConfig` defaults to literal `weasyprint` on Windows, `ExternalAppDepConfig` maps it to the `Weasyprint` group and requires version `58.0` or newer, and pinned `FileToPdf` executes `weasyprint -e utf-8 -v --pdf-forms INPUT OUTPUT`. HTML, Markdown and EML conversion paths use this shared renderer. Version 69.0 retains the exact CLI options Stirling requires, including `-e/--encoding`, `--pdf-forms`, `-u/--base-url` and `-v`.

Candidate payload: official Kozea WeasyPrint **69.0** Windows release asset `weasyprint-windows.zip`, published 2026-06-02, size `29,832,155` bytes, archive SHA-256 `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`, source `https://github.com/Kozea/WeasyPrint/releases/download/v69.0/weasyprint-windows.zip`. This is a Kozea security release addressing CVE-2026-49452. The upstream Windows release workflow builds a Python 3.13/Pango payload into a PyInstaller one-file executable and tests it with `weasyprint --info`.

Permanent candidate components are `.github/scripts/prepare-weasyprint.ps1`, `.github/scripts/weasyprint-launcher.rs` and `.github/scripts/validate-weasyprint.ps1`. Preparation authenticates the exact official archive, extracts only the official executable plus license/readme metadata, stages it at `tools/weasyprint/weasyprint.exe`, and builds `tools/bin/weasyprint.exe` as the literal package-first command Stirling sees. The native shim resolves the backend relative to itself, forwards the complete CLI unchanged, sets child `TEMP`, `TMP` and `TMPDIR` to a unique `data/tmp/weasyprint/run-<pid>-<timestamp>` directory, waits for completion, and removes that invocation directory. Do not add WeasyPrint to the accepted Python/OCRmyPDF lock; this isolated official executable avoids perturbing the accepted Python environment.

The validator must prove exact release archive provenance/hash; AMD64 identity and SHA-256 of both official backend and shim; isolated `where weasyprint` resolution to exactly `tools/bin/weasyprint.exe`; exact version `69.0`; real HTML→PDF execution using Stirling's exact `-e utf-8 -v --pdf-forms` command shape; valid PDF output; no leftover package-local PyInstaller/temp invocation state; and the same proof after relocation to a path containing spaces. With a live backend it must exercise `POST /api/v1/convert/html/pdf` and `POST /api/v1/convert/markdown/pdf`, require valid PDFs, reject `Missing dependency: weasyprint` and `Disabling group: Weasyprint`, require the pinned `69.0` / minimum `58.0` dependency identity while allowing Stirling's patch-normalized `69.0.0` / `58.0.0` log rendering, and require a real `Running command: weasyprint` execution record. HTML/URL/base-URL and EML breadth remains in the representative E2E phase; this block establishes the dependency itself without collapsing later parity testing.

Formal acceptance requires one complete primary workflow run with every earlier accepted gate still green. On success, record run/job/ZIP hash/evidence metadata in README + AGENTS using a documentation-only `[skip ci]` commit, then move the active block to Calibre without triggering a redundant Actions run.

### LibreOffice 26.2.5 + native `unoconvert` — accepted

Do not restart this block from the old wrapper or from `unoserver`. The only architecture is the Stirling Tauri desktop plus bundled Windows LibreOffice and a native package-relative compatibility shim:

- pinned payload: LibreOffice Windows x86-64 `26.2.5` from `https://download.documentfoundation.org/libreoffice/stable/26.2.5/win/x86_64/LibreOffice_26.2.5_Win_x86-64.msi`;
- pinned MSI SHA-256: `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`;
- preparation: `.github/scripts/prepare-libreoffice.ps1` verifies the MSI and uses `msiexec /a` administrative extraction only — never a runner installation — then stages `<portable>/tools/libreoffice/`;
- required payload paths: `tools/libreoffice/program/soffice.com`, `tools/libreoffice/program/soffice.exe`, and `tools/bin/unoconvert.exe`;
- shim source: `.github/scripts/unoconvert-launcher.rs`; it resolves the portable root from its own executable, uses `soffice.com` with `soffice.exe` fallback, provides `--version`, accepts split/equal `--convert-to` and `--input-filter`, ignores split/equal Stirling endpoint metadata (`--host`, `--port`, `--host-location`, `--protocol`), translates to `--infilter`, uses a unique `<portable>/p/` profile plus `<portable>/data/tmp/libreoffice/`, returns the exact requested output path, and removes its profile;
- permanent validator: `.github/scripts/validate-libreoffice.ps1`; it verifies provenance/hash/AMD64, isolated `where` resolution, direct and shim conversions, normal relocation with spaces, package-local state and no package LibreOffice processes. It also owns the actual backend API proof when given the backend URL/log root.

Stirling 2.14.3 facts that must remain preserved: `RuntimePathConfig` defaults to literal `soffice` and `unoconvert`; `ExternalAppDepConfig` probes and groups them independently as `LibreOffice` and `Unoconvert`; `ConvertOfficeController` first calls `unoconvert --convert-to pdf INPUT OUTPUT`; `PDFToFile` first calls `unoconvert --convert-to FORMAT --input-filter=writer_pdf_import INPUT OUTPUT`; and `ProcessExecutor` can inject the four UNO endpoint options. The primary validator therefore requires successful real routes `POST /api/v1/convert/file/pdf` and `POST /api/v1/convert/pdf/word` with field `fileInput` (and `outputFormat=docx` for the latter), backend logs with neither dependency/group disabled, and an actual `Running command: unoconvert` record. The Tauri child is started with package-only PATH entries plus Windows system directories, so a runner installation cannot satisfy this proof.

Candidate history is not product input: `pdf-tunner/libreoffice-uno-candidate` at `8dea43f511771f5483f6b038067cfd39ec7f68e3` / focused Run #13 (`33272788391`, job `99154179041`) established that the shim works, but it is not acceptance. Only its final prepare/shim/validator design was consolidated. Historical diagnostic scripts/workflow from candidate runs #1–#12 are deliberately absent from the primary branch. The documented limitation is LibreOffice sensitivity to extreme Windows path lengths; test and accept ordinary relocation paths containing spaces, not synthetic extreme paths.

### Poppler 26.02.0 — accepted

The candidate pins `oschwartz10612/poppler-windows` release `v26.02.0-0`, asset `Release-26.02.0-0.zip`, SHA-256 `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`. This is a third-party Windows x64 distribution of Poppler upstream and provenance must identify both the upstream project and the binary distributor.

Permanent scripts are `.github/scripts/prepare-poppler.ps1` and `.github/scripts/validate-poppler.ps1`. The payload is staged at `tools/poppler/`; required binaries are `Library/bin/pdftohtml.exe`, `pdfinfo.exe` and `pdfimages.exe`. Preparation must hash the downloaded archive before extraction and persist per-executable hashes without retaining the archive.

The validator must preserve these gates: AMD64 identity; exact archive and executable hashes; isolated package-only `where` resolution; real `pdfinfo`, `pdfimages -list`, `pdftohtml -c`, and `pdftohtml -s -noframes -c` operations against a generated text-and-image PDF; relocation with spaces; final cleanup; and the actual Stirling route `POST /api/v1/convert/pdf/html` with backend logs proving the `Pdftohtml` group was not disabled and `Running command: pdftohtml` occurred.

Complete primary Run #84 (`33502880719`), job `99840040906`, commit `745d87e86096485927a72a0586c4ec5cb969d8c8`, first passed every previous gate and every Poppler gate. Packaged executable SHA-256 values: `pdftohtml.exe` `9fb2802fe026a3ce9967229738e98861b20619b25829f273d3656a05656b0b2f`; `pdfinfo.exe` `34040ff62bef73d6847a7b443457ac7fe216eb331bfbeadec62ae555618b2aae`; `pdfimages.exe` `22ce0c5fc3fac7c19ae526bd3bd3f6fa90592699bb867bf0b62676c72a890d0a`. Post-documentation Run #85 (`33506142322`), job `99850534886`, failed before functional gates on Maven Central HTTP 429 and remains only infrastructure history.

Corrected post-documentation complete primary Run #86 (`33507551477`), job `99855128441`, commit `1b2bfdc4e99d87aa899a0701291db496f740f7ab`, passed all earlier gates and all Poppler gates; this is the formal acceptance evidence. The generated ZIP was `1,463,921,929` bytes, SHA-256 `55C72F44FE4337875D3E0F368AE6067C04C2F65D4A10D9CC3901ED5BBB13FF72`, and was not uploaded. Artifact `9801229105`, `PDF_Tunner-Windows-x64-CI-evidence`, is `1,732` bytes with Actions digest `sha256:294f483bf220d0058faa83fd3ad5a2986039c86266d86021063208cd46acf49a`, expires 2026-09-08, and contains exactly five lightweight files: package evidence, ZIP checksum, layout summary, Poppler provenance and executable checksums. Its layout summary records 28,553 files / 3,367,812,959 payload bytes.

## Primary workflow acceptance contract

Primary path: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency moves to accepted only when the **complete primary workflow** is green with every earlier accepted gate enabled. Record commit SHA, Run/number, job ID, exact source/version/hash and artifact/digest when relevant.

A standalone candidate workflow or `--version` alone is not acceptance. Require real operation and isolated package-first PATH/environment wherever practical.

## CI artifact storage policy

The primary workflow must always build the portable ZIP and execute all acceptance gates. It records the ZIP SHA-256, size, package provenance, Python dependency lock/inventory and layout summary, then uploads only that lightweight CI evidence by default; it must not upload the portable ZIP or Python wheelhouse on ordinary runs. Failure diagnostics are text-only, hard-capped at 2 MB and retained for 3 days. Failure evidence must prioritize bounded package-local backend log tails and concise process/state inventories; never burn the cap on a recursive full-package tree.

The primary workflow must keep npm/Gradle Actions caches disabled; ordinary runs may retain only the bounded text diagnostics and lightweight evidence artifact described above. Desktop preparation may retry a detected Maven Central HTTP 429 up to three attempts with 45/90-second backoff inside the same runner; do not persist its Gradle state as an Actions cache. This policy saves GitHub Actions storage without weakening validation. A large artifact is exceptional, requires a concrete evidence need plus quota/retention review, and must never be retained merely as an archive. The final portable ZIP is a GitHub Release asset only after final v1 acceptance; do not create a Release early.

## Remaining v1 roadmap — do not collapse

### A. External toolchain

1. WeasyPrint;
2. Calibre/`ebook-convert`;
3. `unpaper`;
4. `pngquant`;
5. conversion fonts;
6. explicit VeraPDF E2E;
7. investigate/build/package `jbig2enc` if viable;
8. viable portable RAR/CBR or concrete documented limitation;
9. any further exact dependency exposed during pinned-source parity audit.

### B. Functional validation

Office -> PDF; supported PDF -> Office; HTML/URL -> PDF; WeasyPrint; Poppler; Calibre/EPUB; Python/NumPy/OpenCV; regressions across accepted qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF; `pngquant`/`unpaper`; RAR/CBR and jbig2enc if integrated; representative Stirling API families; explicit proof runner software is not satisfying package tests.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove development push/status/focused diagnostic mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening PR #1;
8. publish clean v1 ZIP only when all gates are complete;
9. manual clean-machine Windows 10/11 checklist.

## Current handoff — 2026-09-03

Accepted/closed: native portable/Tauri containment; Fixed WebView2; qpdf; ImageMagick; Ghostscript; Tesseract; Python 3.12.14 + OCRmyPDF 17.10.0; authenticated 28-package portable Python dependency lock with NumPy 2.5.2; OpenCV via `opencv-python-headless 4.14.0.94` / runtime `4.14.0`; LibreOffice 26.2.5 + native `unoconvert`; Poppler 26.02.0.

Latest green primary regression and OpenCV acceptance evidence: **Run #92** (`33557169326`), job `100020722841`, commit `c4c2b7f6e320840faf3d8c61967351b529875a50`; ZIP SHA-256 `B179CC0CDC50C9BD9A4171F987535979A2380C26519927E753D015F69CF8A23B`, size `1,523,242,671` bytes; evidence artifact `9820918487` (`4,890` bytes), Actions digest `sha256:7c7145e3aed4514ec91328da4393fe0f7626ac7ddfd259fad84461c8eb51a39a`, expires 2026-09-08. Layout: 30,042 package files / 3,537,776,401 payload bytes.

Run #92 passed all earlier gates plus exact OpenCV distribution/runtime identity, package-local AMD64 native validation, real Stirling `split_photos.py` E2E with two valid crops, repeated relocation with spaces, real OCR/NumPy regressions, backend acceptance, state/process cleanup and final ZIP/layout validation. Run #91 remains only the validator-semantic history that led to the corrected check. **OpenCV is formally accepted.**

Active candidate: **WeasyPrint 69.0**, official Kozea Windows PyInstaller release asset, SHA-256 `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`. Candidate architecture is official backend `tools/weasyprint/weasyprint.exe` plus package-relative `tools/bin/weasyprint.exe` shim localizing per-invocation temp to `data/tmp/weasyprint`. Acceptance gates include authenticated provenance/hash, AMD64, isolated PATH, exact Stirling CLI, real HTML→PDF, relocation with spaces, real backend HTML→PDF and Markdown→PDF, dependency-group logs and final full-regression ZIP/evidence. It is **not accepted** until the complete primary workflow is green.

Primary Run #94 (`33666446582`), job `100369276881`, commit `3afffbc52eb2450eede8ea112ce0628a0bd8b3c4`, supplied the exact cause that Run #93 could not preserve. The bounded diagnostic collector succeeded and retained artifact `9861833508`, 23,595 bytes, digest `sha256:27b7957e29c3f168144ac6fc1da9ef39e3c6aa8635637e5a6c34a9804e18926c`, expiring 2026-09-05. Backend logs prove Stirling actually started on dynamic port `54686`, logged `Stirling-PDF Started`, kept the WeasyPrint group enabled, and executed real package-local `weasyprint` commands for both HTML→PDF and Markdown→PDF.

The #94 failure is validator-only: Stirling normalizes the dependency log to `WeasyPrint 69.0.0 meets minimum 58.0.0`, while the validator demanded the shorter literal `WeasyPrint 69.0 meets minimum 58.0`. The targeted correction may only make this log assertion semantically patch-normalization-aware; it must not change the `69.0` payload, archive hash, shim, PATH, CLI, endpoints, timeout, accepted dependency versions or any earlier gate. After the correction, run exactly one complete primary regression. Do not start Calibre meanwhile.

## Compact changelog

- **2026-08-21–23:** real fork/base confirmed; Stirling Tauri + JLink architecture selected; portable state containment and two-launch window-state proof established.
- **2026-08-27:** Fixed WebView2 accepted #62; qpdf #66; ImageMagick #67; Ghostscript #68; Tesseract #70.
- **2026-08-28:** OCRmyPDF candidate built around pinned relocatable Python standalone + native relative launcher + real searchable-PDF/relocation validation.
- **2026-08-28:** focused OCRmyPDF Run #5 passed fully; primary Run #76 reconfirmed the prior baseline.
- **2026-08-28:** primary Run #77 passed with Python/OCRmyPDF integrated, real OCR, relocation, backend dependency acceptance, final ZIP and SHA-256. Python/OCRmyPDF accepted.
- **2026-08-29:** temporary OCRmyPDF candidate workflow retired; primary Run #78 reconfirmed the accepted baseline.
- **2026-08-29:** LibreOffice 26.2.5 focused candidate Run #13 passed isolated extraction/shim/relocation probes.
- **2026-09-01:** primary Run #82 passed all gates with LibreOffice/unoconvert plus real backend conversions; retained CI evidence is 958 bytes.
- **2026-09-01:** post-documentation primary Run #83 passed every gate; ZIP SHA-256 and a 957-byte evidence artifact were retained. LibreOffice 26.2.5 + native `unoconvert` accepted; Poppler became the active block.
- **2026-09-01:** Poppler 26.02.0 Windows x64 candidate integrated with pinned archive hash, isolated direct/relocation gates and real Stirling PDF→HTML backend proof.
- **2026-09-01:** complete primary Run #84 passed every previous and Poppler gate; generated ZIP SHA-256 `5146303DEC1D4D37E88217D9DB32422411198944C95182693CF0F38909120FA0`; retained evidence is 1,727 bytes. Formal acceptance pending the post-documentation regression.
- **2026-09-01:** post-documentation Run #85 failed before functional gates on Maven Central HTTP 429; added bounded same-runner retry/backoff while keeping Actions caches disabled.
- **2026-09-01:** corrected post-documentation primary Run #86 passed every gate; the ZIP was generated, validated and hashed but not uploaded, retained evidence is 1,732 bytes, and Poppler 26.02.0 is formally accepted.
- **2026-09-01:** replaced open-ended OCRmyPDF transitive resolution with a 27-package CPython 3.12 Windows x64 lock, per-wheel hashes, authenticated wheelhouse download, offline installation and exact runtime inventory gates; primary acceptance pending.
- **2026-09-01:** complete primary Run #87 passed every prior and Python-lock gate; generated ZIP SHA-256 `9F1BA2BCF2452C47D864ECE91AB4FBA876D4567502A1D398C6DE69A77C704E5C`; retained evidence is 4,545 bytes. The authenticated portable Python dependency lock is formally accepted; NumPy is next.
- **2026-09-01:** integrated the NumPy 2.5.2 CPython 3.12 Windows AMD64 wheel into a 28-package authenticated lock with package-local compiled-core/DLL, deterministic matrix and relocation gates; complete primary acceptance pending.
- **2026-09-01:** primary Run #88 stopped before functional gates on a transient connector-status transport closure; bounded the auxiliary bridge to two useful statuses with short retry/time limits, preserving every acceptance gate and lightweight-storage rule.
- **2026-09-01:** corrective primary Run #89 exposed `$RunId:` as invalid PowerShell interpolation during preflight; retained only a 1,309-byte text diagnostic, built no ZIP, and corrected the expression to `${RunId}:` without changing any functional gate.
- **2026-09-01:** complete primary Run #90 passed every prior gate plus authenticated NumPy 2.5.2 package-local AMD64, deterministic matrix and relocation validation; generated ZIP SHA-256 `B1E7FB8E38DA90992FCBDC63118B7E8BEDE644EA434693AA2F1062B38709F473`; retained evidence is 4,727 bytes. NumPy is formally accepted; OpenCV is next.
- **2026-09-01:** prepared the OpenCV 4.14.0.94 headless candidate around a dedicated authenticated Windows x64 wheel lock, package-local AMD64 checks, real pinned `split_photos.py` E2E, relocation with spaces and backend dependency-group validation; complete primary acceptance pending.
- **2026-09-01:** primary Run #91 authenticated and packaged OpenCV 4.14.0.94 and passed the NumPy gate, then exposed a validator-only distribution/runtime version conflation (`4.14.0.94` vs `cv2.__version__=4.14.0`). Corrective validation now checks both identities separately without changing the payload or weakening any functional gate.
- **2026-09-01:** complete primary Run #92 passed every earlier gate plus corrected OpenCV distribution/runtime, AMD64 native, real `split_photos.py`, relocation and backend checks; generated ZIP SHA-256 `B179CC0CDC50C9BD9A4171F987535979A2380C26519927E753D015F69CF8A23B`; retained evidence is 4,890 bytes. OpenCV is formally accepted; WeasyPrint is next.
- **2026-09-02:** prepared the authenticated WeasyPrint 69.0 candidate from Kozea's official Windows release asset with native package-relative temp-containment shim, AMD64/hash/PATH/direct HTML→PDF/relocation gates and real Stirling HTML→PDF + Markdown→PDF backend validation; complete primary acceptance pending.
- **2026-09-02:** Run #93 proved the isolated WeasyPrint candidate but failed before live-backend acceptance because no dynamic port was detected; replaced the oversized recursive failure snapshot with a bounded backend-log-focused collector so the next single full regression can expose the actual startup cause without relaxing timeouts or acceptance gates.
- **2026-09-02:** Run #94 preserved bounded backend logs and proved the backend plus both real WeasyPrint conversion routes were healthy; the remaining failure is a validator-only `69.0`/`58.0` versus Stirling `69.0.0`/`58.0.0` log-format mismatch. Correct only that semantic assertion and rerun the complete primary workflow once.
