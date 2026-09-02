# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**
- No final PDF_Tunner v1 Release exists yet; `main` remains the clean upstream base during portable development.

## Accepted portable layers

The complete primary Windows workflow has accepted:

- native Tauri/JRE portable bootstrap, package-local backend state, Java temp, WebView2 profile, Tauri stores/logs/cookies/window state and shutdown containment;
- Fixed WebView2 `151.0.4129.101` x64;
- qpdf `12.4.0` MinGW64;
- ImageMagick `7.1.2-30` portable Q16 x64;
- Ghostscript `10.07.1` Win64;
- Tesseract OCR release `5.5.3`, Windows CLI `5.5.3.20260724`, with pinned `eng`, `spa` and `osd` models;
- Python `3.12.14` x64 portable runtime with an authenticated 28-package dependency lock including NumPy `2.5.2`;
- OCRmyPDF `17.10.0` with a package-relative native launcher;
- OpenCV via authenticated `opencv-python-headless 4.14.0.94` (OpenCV runtime/core `4.14.0`), with package-local AMD64 and real Stirling `split_photos.py` E2E validation;
- LibreOffice `26.2.5` with package-relative native `unoconvert.exe`;
- Poppler `26.02.0` Windows x64 with package-local `pdftohtml`, `pdfinfo` and `pdfimages`.

### Python + OCRmyPDF — accepted

Stirling 2.14.3 probes and executes the external command `ocrmypdf`. PDF_Tunner packages:

- Python `3.12.14` x64 from `astral-sh/python-build-standalone`, release `20260825`, `install_only_stripped` Windows MSVC archive;
- Python archive SHA-256 `8e6aad12ef6fc9685e67ce66253f8f72d6e8fa02cb7187e5850bd4db5ecd9e2a`;
- OCRmyPDF `17.10.0` from PyPI;
- OCRmyPDF wheel SHA-256 `34ba1b595ecacc94b6dc3c9d4fa51953de63082cd16cf8595251bd72120b930a`.

Run #87 accepted the 27-package baseline of `.github/config/ocrmypdf-py312-windows-x64.lock.txt` at SHA-256 `d58c07e22837967fbbefb1f9f5168c100bfe47535c88445ccbad156f7fcd1374`. It pins every OCRmyPDF/runtime package to an exact version and authenticates the selected CPython 3.12 Windows x64/universal wheel for each package. Preparation downloads only that hash-locked wheelhouse, verifies its exact count and hashes, then installs from the local wheelhouse with network access disabled. Validation rejects missing, changed or unexpected non-bootstrap packages, compares the installed inventory with the packaged lock, runs `pip check`, and preserves the existing real OCR, searchable-text and relocation gates.

Complete primary Run #87 (`33521994024`), job `99903300606`, commit `b18ff6d5b6cc1ebc22a142f970e5d221f66485ed`, passed every earlier gate plus authenticated download of all 27 wheels, offline installation, exact live inventory checks, repeated clean `pip check`, real OCR/searchable-text validation and relocation with spaces. It generated and validated a `1,463,925,596`-byte ZIP with SHA-256 `9F1BA2BCF2452C47D864ECE91AB4FBA876D4567502A1D398C6DE69A77C704E5C`; the ZIP and wheelhouse were not uploaded. Retained artifact `9807333187`, `PDF_Tunner-Windows-x64-CI-evidence`, is only `4,545` bytes, digest `sha256:33151eacdedd60fafe84e34fbeeb947716b651d35aee7dac0704dee172ea68cd`, expires 2026-09-08, and contains eight lightweight evidence files. Its layout summary records 28,579 files / 3,367,817,902 payload bytes. The portable Python dependency lock is formally accepted.

PDF_Tunner removes the pip-generated Windows console launcher and builds `tools/python/ocrmypdf.exe`, a native relative shim that resolves sibling `python.exe`, executes `python.exe -m ocrmypdf`, writes OCRmyPDF temp state to `data/tmp/ocrmypdf/`, and Python cache to `data/python-cache/`.

Primary Run **`33201568275` (#77)**, job **`98952028665`**, commit **`54802c15427673c0e95738195947ab76239d6e31`**, completed successfully with every prior gate enabled. It proved exact pinned versions/hashes, isolated package-only resolution, real searchable-PDF OCR, text extraction, package-local temp/cache, relocation to a path containing spaces, real backend acceptance of `ocrmypdf`, final layout cleanup, ZIP creation and SHA-256.

Run #77 artifact: **`9698621272`**, `PDF_Tunner-Windows-x64-Portable-bootstrap`, GitHub Actions digest **`sha256:68f69bb0d4ed6b731aefee82abff3eba7b01d18c5b270051e2e546337cd6a164`**. This is CI evidence only, not the final v1 Release.

The temporary focused OCRmyPDF workflow has been retired from automatic execution after primary acceptance. It remains manual-only temporarily and must be physically removed during final CI cleanup.

### NumPy 2.5.2 — accepted

The accepted Python lock now contains 28 packages including NumPy `2.5.2`. The exact CPython 3.12 Windows AMD64 wheel is authenticated by SHA-256 `28ac63476ec7651484215ee7fa15a1f78b57c14621f01e392afe17b9a1390ce4`; the resulting complete lock SHA-256 is `ededb999049d81b85527f4d4aa679179e747669df300083d91bc2dd4e14e430f`. Stirling's `split_photos.py` imports NumPy together with OpenCV, so NumPy establishes the compiled numerical base used by the accepted OpenCV block.

Preparation retains the same authenticated download and offline installation model. Validation proves the exact live version, package-local module and compiled core paths, AMD64 identity of the core extension and bundled native DLLs, and deterministic matrix multiplication. The complete probe repeats after relocation to a path containing spaces, while every prior OCR and portable gate remains enabled. Ordinary CI still retains only the small lock, inventory and provenance evidence; it does not upload the wheelhouse or portable ZIP.

Primary Run #88 (`33528451159`), job `99925173576`, commit `b02b7f89a38f370c2102e4aea61aabe9e259ef67`, stopped before every functional gate when the auxiliary connector-status bridge replayed historical status writes and GitHub closed the transport connection. No portable payload or evidence artifact was produced; this is not NumPy evidence. The bridge is now bounded to the current run plus the latest completed predecessor, uses short timeouts/retries, and remains explicitly auxiliary so a status-publication outage cannot replace or block the functional acceptance gates.

Corrective primary Run #89 (`33529648123`), job `99929237590`, commit `92edd653e62cdd6d6e04f59889eac2c90e1b9ed9`, then failed deterministically in the PowerShell preflight because the bridge warning string used the invalid interpolation `$RunId:`. It therefore ran no functional gate and built no ZIP or payload. The only retained output is text-only diagnostic artifact `9809195211`, `PDF_Tunner-startup-diagnostics`, at `1,309` bytes with digest `sha256:8e89549f40c874137c13db9a741f48d5eb16607a851e7f8aa21fad2a4fb0e792`, expiring 2026-09-04. The interpolation was corrected to `${RunId}:`; this run did not count as NumPy acceptance evidence.

Complete primary Run #90 (`33530454097`), job `99931980241`, commit `c32fb84eb2c0f7b157ef3217c59e57eee20b895b`, passed every earlier gate plus exact 28-package lock/inventory checks, package-local NumPy compiled-core/DLL AMD64 validation, deterministic matrix multiplication and the repeated relocation probe with spaces. It generated and validated a `1,480,791,164`-byte ZIP with SHA-256 `B1E7FB8E38DA90992FCBDC63118B7E8BEDE644EA434693AA2F1062B38709F473`; the ZIP and wheelhouse were not uploaded. Retained artifact `9810633011`, `PDF_Tunner-Windows-x64-CI-evidence`, is only `4,727` bytes, digest `sha256:d47a3e77de6788a32a6b9287452d53507b7c6ab04ba5e5aad15b259f4b72d0f9`, expires 2026-09-08, and contains eight lightweight evidence files. Its layout summary records 29,936 files / 3,421,683,208 payload bytes. NumPy 2.5.2 is formally accepted.

### OpenCV 4.14.0.94 — accepted

Pinned Stirling 2.14.3 contains `app/core/src/main/resources/static/python/split_photos.py`, which imports `cv2` + NumPy and uses OpenCV for thresholding, dilation, contour detection, auto-rotation and PNG output. `ExternalAppDepConfig` separately probes OpenCV through package-local Python with `import cv2`.

PDF_Tunner intentionally uses the **headless main-modules** wheel because the pinned Stirling script performs image processing only and does not use OpenCV GUI calls. The accepted distribution is `opencv-python-headless 4.14.0.94`, Windows x64 wheel `opencv_python_headless-4.14.0.94-cp37-abi3-win_amd64.whl`, SHA-256 `cbed65415b8f6a9541c705afe3e64795840524d0ff3bc58f507826284a1dc64b`. PyPI declares `numpy>=2` for Python >=3.9, satisfied by accepted NumPy `2.5.2`.

To preserve the formally accepted 28-package OCRmyPDF/NumPy lock unchanged, OpenCV uses a dedicated one-package authenticated lock at `.github/config/opencv-py312-windows-x64.lock.txt`, SHA-256 `ec341586a884015445d4e28debbdd00b57ac903a36405bc7e0b9020e12dfd6c6`. The existing Python preparation downloads this wheel separately with `--require-hashes`, verifies its exact filename/platform/hash, installs it offline after the accepted base wheelhouse and records the OpenCV pin/lock in package provenance. The combined installed inventory must equal the accepted 28 packages plus this single OpenCV distribution.

The validator preserves every existing Python/OCRmyPDF/NumPy gate and additionally proves package-local `cv2` resolution, the exact installed PyPI distribution version `4.14.0.94`, the exact OpenCV runtime/core version reported by `cv2.__version__` (`4.14.0`), AMD64 identity of all packaged `.pyd`/DLL native payloads, a synthetic real execution of Stirling's own `split_photos.py` producing two expected cropped images, repetition after relocation to a path containing spaces, and absence of `Missing dependency: Python with OpenCV` / `Disabling group: OpenCV` in backend logs. Distribution and runtime versions are intentionally validated as separate identities because the `opencv-python` wheel build component (`.94`) is not part of `cv2.__version__`.

Primary Run #91 (`33539166188`), job `99960820047`, commit `92643f78737dc64e851156d23050a61927ba60bf`, authenticated and installed the correct candidate but exposed a validator-only semantic error: the first OpenCV comparison incorrectly treated distribution `4.14.0.94` and runtime/core `4.14.0` as the same version string. The corrective commit `c4c2b7f6e320840faf3d8c61967351b529875a50` split those checks without changing the wheel, lock, hashes, packaging or functional gates.

Complete primary Run #92 (`33557169326`), job `100020722841`, commit `c4c2b7f6e320840faf3d8c61967351b529875a50`, passed every previously accepted gate plus the corrected OpenCV distribution/runtime identity checks, package-local AMD64 native validation, real pinned Stirling `split_photos.py` E2E producing exactly two valid crops, the repeated relocation-with-spaces probe, real OCR/NumPy regressions, backend validation, portable-state/process cleanup, final layout validation and ZIP creation. It generated and validated a `1,523,242,671`-byte ZIP with SHA-256 `B179CC0CDC50C9BD9A4171F987535979A2380C26519927E753D015F69CF8A23B`; the ZIP and wheelhouse were not uploaded. Retained artifact `9820918487`, `PDF_Tunner-Windows-x64-CI-evidence`, is only `4,890` bytes, digest `sha256:7c7145e3aed4514ec91328da4393fe0f7626ac7ddfd259fad84461c8eb51a39a`, expires 2026-09-08, and contains eight lightweight evidence files. Its layout summary records `30,042` files / `3,537,776,401` payload bytes. **OpenCV is formally accepted. WeasyPrint is the active external-toolchain block.**

### WeasyPrint 69.0 — active candidate

Pinned Stirling 2.14.3 resolves the literal Windows command `weasyprint` through `RuntimePathConfig`, and `ExternalAppDepConfig` requires version `58.0` or newer before leaving the `Weasyprint` feature group enabled. Its shared `FileToPdf` path invokes `weasyprint -e utf-8 -v --pdf-forms INPUT OUTPUT`; the same conversion layer is used by HTML, Markdown and EML conversion paths.

The candidate pins the official Kozea **WeasyPrint 69.0** Windows release asset `weasyprint-windows.zip`, published 2026-06-02. The archive is `29,832,155` bytes and has SHA-256 `330101ff3ea50ebde4abf805283b6d703d5f3d71c77c983db94357ec4524a3ef`; source URL: `https://github.com/Kozea/WeasyPrint/releases/download/v69.0/weasyprint-windows.zip`. Version 69.0 is also a security release addressing CVE-2026-49452. Kozea's release workflow builds the Windows executable with PyInstaller one-file mode and validates it with `weasyprint --info`.

PDF_Tunner stages the authenticated official executable at `tools/weasyprint/weasyprint.exe` and builds a small package-relative native shim at `tools/bin/weasyprint.exe`, where Stirling's literal probe already resolves first. The shim forwards the complete CLI unchanged, localizes PyInstaller/child `TEMP`, `TMP` and `TMPDIR` to a unique `data/tmp/weasyprint/run-<pid>-<timestamp>/` directory, waits for completion, then removes that per-invocation directory. This keeps the accepted Python/OCRmyPDF/NumPy/OpenCV environment untouched.

The primary candidate gate independently verifies exact release archive SHA/provenance, AMD64 identity and packaged executable/shim hashes; proves isolated `where weasyprint` resolves only to `tools/bin/weasyprint.exe`; checks exact version `69.0`; performs a real HTML→PDF conversion with Stirling's exact `-e utf-8 -v --pdf-forms` options; rejects residual per-invocation temp state; and repeats the complete runtime proof after relocation to a Windows path containing spaces. The live-backend gate then exercises real `POST /api/v1/convert/html/pdf` and `POST /api/v1/convert/markdown/pdf` requests, requires valid PDF output, checks that the backend reports `WeasyPrint 69.0 meets minimum 58.0`, and rejects missing/disabled dependency logs while requiring a real `Running command: weasyprint` execution record.

WeasyPrint remains **candidate/pending** until one complete primary `PDF_Tunner Windows Portable` run passes with every previously accepted gate still enabled. HTML/URL→PDF breadth, including explicit URL/base-URL coverage and EML regression, remains part of the broader representative E2E phase even after this dependency block is accepted.

### LibreOffice 26.2.5 + native `unoconvert` — accepted

The complete primary regression is green, including the real backend routes. LibreOffice and the native `unoconvert` compatibility shim are formally accepted on the evidence of primary Run #83. The integration pins the official The Document Foundation Windows x86-64 MSI:

- LibreOffice `26.2.5`;
- source: `https://download.documentfoundation.org/libreoffice/stable/26.2.5/win/x86_64/LibreOffice_26.2.5_Win_x86-64.msi`;
- MSI SHA-256 `f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9`.

CI performs MSI **administrative extraction only**; it never installs LibreOffice on the runner. The resulting payload is `tools/libreoffice/`, including `program/soffice.com` and `program/soffice.exe`. It builds `tools/bin/unoconvert.exe` from `.github/scripts/unoconvert-launcher.rs`: a native, package-relative compatibility shim which invokes bundled `soffice.com` (with `soffice.exe` fallback), creates a unique temporary LibreOffice profile under `p/`, localizes child `TEMP`/`TMP` to `data/tmp/libreoffice/`, and cleans the profile after every operation.

The shim intentionally does **not** run `unoserver`. It accepts Stirling's `--convert-to` and `--input-filter` split/equal forms, safely ignores the injected UNO endpoint metadata (`--host`, `--port`, `--host-location`, `--protocol` in both forms), translates the input filter to `--infilter`, and moves LibreOffice's output to Stirling's exact requested output path.

The primary gate stages provenance and hashes, proves `where soffice` and `where unoconvert` resolve only inside the package with `tools/bin` first, runs direct `soffice` DOCX -> PDF plus shim DOCX -> PDF and PDF -> DOCX (`writer_pdf_import`), moves an already-used full portable tree between ordinary Windows paths containing spaces, and checks package-local temp/profile cleanup and no bundled LibreOffice process remains. It then starts the actual Tauri/Stirling backend with a package-only inherited `PATH`, verifies that `ExternalAppDepConfig` has not disabled either LibreOffice or Unoconvert, and exercises `/api/v1/convert/file/pdf` and `/api/v1/convert/pdf/word`.

Focused candidate Run #13 (`33272788391`, job `99154179041`, commit `8dea43f511771f5483f6b038067cfd39ec7f68e3`) validated the isolated payload/shim design only. Complete primary Run #83 (`33497784837`), job `99823839704`, commit `355c0cf5cfe7afaadd89933a0aa3fb13456ebb83`, passed every prior gate plus direct/shim DOCX→PDF and PDF→DOCX, normal relocation with spaces, package-local cleanup, and real Stirling Office→PDF/PDF→DOCX backend routes. It generated ZIP SHA-256 `1F0D6AE03FD5F0A6158128669517E5378CADE9B1BE358DE0272600ED9126D105`; retained evidence artifact `9797397461` is 957 bytes, digest `sha256:9a3ac1af4d03dcae8b69cda20fc5f2f824c5486a7112991f112addd2fc9cdb12`, expiring 2026-09-08. LibreOffice is known to be sensitive to unusually extreme Windows path lengths; v1 acceptance requires normal relocation and spaces, not artificially extreme paths.

### Poppler 26.02.0 — accepted

The accepted portable packages Poppler `26.02.0` for Windows x64 from the `oschwartz10612/poppler-windows` binary distribution, release `v26.02.0-0`:

- source asset: `https://github.com/oschwartz10612/poppler-windows/releases/download/v26.02.0-0/Release-26.02.0-0.zip`;
- archive SHA-256: `993e4a94376ed712fafc7058d724ea0b943d118bbd2305cd9ed55174eb85cda5`;
- package layout: `tools/poppler/Library/bin/`, including `pdftohtml.exe`, `pdfinfo` and `pdfimages.exe`.

This is a pinned third-party Windows build of the Poppler upstream project, not an official Windows binary published by Poppler itself; provenance records both projects explicitly. Stirling 2.14.3 probes the literal command `pdftohtml` and its PDF-to-HTML/Markdown implementation uses `-c`, plus `-s -noframes -c` for Markdown.

The primary gate verifies the release hash, each packaged executable hash and AMD64 PE identity; proves isolated package-only command resolution; runs real `pdfinfo`, `pdfimages -list` and both exact `pdftohtml` option forms against a generated one-page PDF containing text and an image; repeats execution after relocation to a path containing spaces; and exercises Stirling's real `POST /api/v1/convert/pdf/html` route with backend log proof that package-local `pdftohtml` ran.

Complete primary Run #84 (`33502880719`), job `99840040906`, commit `745d87e86096485927a72a0586c4ec5cb969d8c8`, first passed every previous gate plus all Poppler direct, isolated, relocation and real backend PDF→HTML checks. Executable SHA-256 values were `9fb2802fe026a3ce9967229738e98861b20619b25829f273d3656a05656b0b2f` (`pdftohtml.exe`), `34040ff62bef73d6847a7b443457ac7fe216eb331bfbeadec62ae555618b2aae` (`pdfinfo.exe`) and `22ce0c5fc3fac7c19ae526bd3bd3f6fa90592699bb867bf0b62676c72a890d0a` (`pdfimages.exe`). Post-documentation Run #85 (`33506142322`), job `99850534886`, stopped before functional gates on Maven Central HTTP 429; it is recorded as an upstream rate-limit failure, not Poppler evidence.

Corrected post-documentation primary Run #86 (`33507551477`), job `99855128441`, commit `1b2bfdc4e99d87aa899a0701291db496f740f7ab`, passed every gate and formally accepts Poppler. It generated and validated a `1,463,921,929`-byte ZIP with SHA-256 `55C72F44FE4337875D3E0F368AE6067C04C2F65D4A10D9CC3901ED5BBB13FF72`; the ZIP was not uploaded. Retained artifact `9801229105`, `PDF_Tunner-Windows-x64-CI-evidence`, is only `1,732` bytes, has Actions digest `sha256:294f483bf220d0058faa83fd3ad5a2986039c86266d86021063208cd46acf49a`, expires 2026-09-08, and contains five small evidence files: package metadata, ZIP checksum, layout summary, Poppler provenance and executable checksums. The recorded portable layout is 28,553 files / 3,367,812,959 payload bytes.

## Architecture

PDF_Tunner uses Stirling's own Tauri desktop app in `frontend/editor/src-tauri`. Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`.

State is localized component by component:

- Stirling backend config/logs/working state -> `data/`;
- Java temp -> `data/tmp/`;
- WebView2 profile -> `data/webview2/`;
- Tauri logs/store/cookies/window state -> `data/tauri/...`;
- ImageMagick temp -> `data/tmp/imagemagick/`;
- Tesseract models -> `tools/tesseract/tessdata/`;
- Python/OCRmyPDF -> `tools/python/`;
- OCRmyPDF temp -> `data/tmp/ocrmypdf/`;
- Python cache -> `data/python-cache/`;
- LibreOffice -> `tools/libreoffice/`; `unoconvert.exe` -> `tools/bin/`;
- LibreOffice child temp -> `data/tmp/libreoffice/`; transient shim profiles -> `p/`;
- Poppler -> `tools/poppler/`, with executables under `Library/bin/`;
- WeasyPrint official Windows payload -> `tools/weasyprint/`; portable command shim -> `tools/bin/weasyprint.exe`; per-invocation temp -> `data/tmp/weasyprint/`;
- Calibre config -> `data/calibre/` when added.

Portable mode also skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## External dependency source of truth

The dependency inventory is source-backed from Stirling 2.14.3, especially `ExternalAppDepConfig`, `RuntimePathConfig`, the Docker toolchain and controllers/services that execute each feature.

| Capability | Stirling runtime probe |
| --- | --- |
| Ghostscript | `gs` |
| OCRmyPDF | `ocrmypdf` |
| LibreOffice | `soffice` |
| WeasyPrint | `weasyprint` (minimum 58) |
| Poppler HTML conversion | `pdftohtml` |
| UNO conversion | `unoconvert` |
| qpdf | `qpdf` (minimum 12) |
| Tesseract | `tesseract` |
| CBR/RAR | `rar` |
| Calibre | `ebook-convert` |
| ImageMagick | `magick` |
| Python | `python3` or `python` |
| OpenCV | Python `import cv2` |

Also audit Poppler helpers (`pdfinfo`, `pdfimages`), `unpaper`, `pngquant`, NumPy/OpenCV, WeasyPrint, LibreOffice/UNO, Calibre, conversion fonts, VeraPDF E2E, `jbig2enc` and any additional exact dependency exposed by pinned source.

## Validation contract

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. `--version` alone is never sufficient.

## CI artifact storage policy

The primary workflow always builds the portable ZIP and verifies its layout, functional gates, size and SHA-256. Ordinary CI retains only a small evidence artifact containing the package hash, size, provenance, Python dependency lock/inventory and layout summary; it does not upload the multi-gigabyte ZIP itself. Failure diagnostics are text-only, capped at 2 MB and retained for 3 days. The bounded startup collector retains selected package-local backend log tails plus concise process/state inventories; it deliberately does not retain a recursive full-package tree.

The primary workflow also leaves npm/Gradle Actions caches disabled, so ordinary runs do not persist dependency caches against the 0.5 GB storage allowance. Transient Maven Central HTTP 429 failures during desktop preparation are retried up to three times with bounded backoff inside the same runner; any runner-local Gradle state disappears with the job and is not uploaded. This preserves full regression coverage without consuming GitHub Actions storage for every iteration. Large ZIP retention is exceptional and must be justified before upload. The final user-deliverable ZIP will be attached to the GitHub Release only after the complete v1 acceptance process; no Release exists yet.

## Remaining v1 roadmap

1. Validate and accept WeasyPrint.
2. Calibre/`ebook-convert`; `unpaper`; `pngquant`; conversion fonts; explicit VeraPDF E2E; investigate `jbig2enc`; establish viable RAR/CBR support or document the limitation; add any further dependency found in exact pinned source.
3. Representative E2E operations across OCR, Office, HTML/URL -> PDF, accepted Poppler, WeasyPrint, Calibre/EPUB, Python/OpenCV and representative Stirling API families.
4. Non-Enterprise parity audit against Stirling 2.14.3.
5. Final branding and portability audits.
6. CI/repository cleanup, including physical removal of the retired OCRmyPDF candidate workflow, and downstream diff hygiene review.
7. Final docs/provenance/version/hash record.
8. Integrate to `main` without reopening old PR #1.
9. Publish the clean v1 portable ZIP only after all gates, then perform the manual clean-machine Windows 10/11 checklist.

## Mandatory documentation rule

**Every PDF_Tunner-specific repository change must update both `README.md` and `AGENTS.md` in the same final commit.**

## Active diagnostic continuation — WeasyPrint Run #93

Primary Run #93 (`33621678436`), attempt 2, job `100256100825`, commit `4a8cae2ee848c86c01f13c0452ff014df35ace19`, passed WeasyPrint staging plus the isolated package-local version/hash/AMD64/HTML-to-PDF/relocation gate and every previously accepted dependency gate up to bundled Java validation. It then failed in `Start PDF_Tunner and validate real backend` because the startup gate did not detect the dynamic backend port from package-local logs within its existing 150-second window. WeasyPrint is therefore still **candidate/pending**, not accepted.

The #93 failure snapshot showed the packaged desktop stack had progressed well beyond an immediate crash: the PDF_Tunner/WebView2 stack and bundled Java were present and package-local backend log files had been created. The old failure collector did not preserve those log contents; instead it generated a multi-megabyte recursive portable-tree listing and then failed its own 2 MB retention cap. That is an observability defect, not a diagnosis of the backend failure.

The primary workflow now delegates failure evidence to `.github/scripts/collect-startup-diagnostics.ps1`. The collector retains bounded tails from package-local backend logs, includes `weasyprint` in the process snapshot, keeps concise host/data/WebView2/layout evidence, removes optional snapshots if necessary, and preserves the existing 2 MB / 3-day policy without retaining the full portable tree. No backend timeout, WeasyPrint payload, accepted dependency, or functional gate is relaxed by this diagnostic-only change. The next primary run must either go green or provide the exact backend log tail needed for a targeted correction before any further dependency is added.
