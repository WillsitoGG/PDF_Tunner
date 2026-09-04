# PDF_Tunner

**PDF_Tunner** is a Windows 10/11 x64 portable tuning of the real, complete [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF) codebase. `WillsitoGG/PDF_Tunner` is a real GitHub fork: PDF_Tunner tunes Stirling directly rather than rebuilding it behind a separate wrapper.

## Base and current status

- Upstream: `Stirling-Tools/Stirling-PDF`
- Upstream version: **2.14.3**
- Pinned upstream snapshot: `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`
- Development branch: `pdf-tunner/windows-portable-v1`
- Target: **Windows 10/11 x64 portable ZIP**, extract and run without installation.
- `main` remains the clean pinned upstream base during v1 development.
- No final PDF_Tunner v1 Release exists yet.
- Latest complete green primary regression: **Run #99** (`33786563784`), job `100752651171`, commit `8d4d3906f6535c5a0e214cf96948e19de0678a23`.
- **unpaper 6.1 + pngquant 2.17.0 are formally accepted by Run #99.**
- Active external-toolchain candidate: **package-local conversion fonts**, focused on the CJK gap not already supplied by the accepted LibreOffice runtime.
- Run #100 (`33791580636`), job `100769194852`, candidate commit `6b88a09cbd0ba286ca67c5378257171e17fd2931`, failed only when the LibreOffice wrapper entered the new conversion-font staging layer; primary steps 1–31 remained green. Conversion fonts are therefore still a candidate, not accepted.

## Accepted portable layers

| Layer | Accepted identity / evidence |
| --- | --- |
| Native Tauri/JRE portable bootstrap | package-local backend/Tauri/WebView2/temp state and process containment; consolidated state proof includes Run `32825188381` |
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
| Calibre | official Windows x64 `9.14.0`, package-relative `ebook-convert`, real PDF↔eBook routes; Run #96 `33748509811` |
| **OCRmyPDF auxiliaries** | **unpaper `6.1` + pngquant `2.17.0`; Run #99 `33786563784`** |

## Latest acceptance — unpaper 6.1 + pngquant 2.17.0

Pinned Stirling 2.14.3 installs `unpaper` and `pngquant` in its standard runtime image. Their Windows portable behavior is mediated through the already accepted OCRmyPDF `17.10.0` runtime:

- `unpaper` is used by OCRmyPDF for `--clean` / `--clean-final`;
- `pngquant` is used by OCRmyPDF optimization levels 2 and 3;
- OCRmyPDF probes literal commands on `PATH` and has no minimum-version gate for either utility.

Accepted payloads:

- **unpaper 6.1 Windows x86_64 community build** from `rodrigost23/unpaper`; archive SHA-256 `a760fa1fb5a076c7dad24c643aaec5330473ab03fbf6ede50e124978d840ee65`;
- **pngquant 2.17.0** from the official `https://pngquant.org/pngquant-windows.zip`; archive SHA-256 `bd0257aeeccfe446a4cd764927e26f8af6051796f28abed104307284107b120d`. The authenticated executable self-reports `2.17.0 (September 2021)`.

Runs #97 and #98 were diagnostic failures. #98 proved the candidate had incorrectly labelled the authenticated pngquant payload as 3.0.3. The version expectation was corrected without weakening archive authentication, AMD64 identity, package-first resolution, OCRmyPDF ToolProbe, real wrapper execution, `--clean --clean-final`, or relocation tests.

**Complete primary Run #99 (`33786563784`), job `100752651171`, commit `8d4d3906f6535c5a0e214cf96948e19de0678a23`, passed every primary step and formally accepts unpaper 6.1 + pngquant 2.17.0.**

Run #99 evidence:

- ZIP: `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`
- ZIP size: `1,861,405,214` bytes
- ZIP SHA-256: `5AFD552CFDF4DCEF48151470154541694AAFC5E1DD6650E913D2BDBD6D51496F`
- portable layout: `31,468` files / `4,303,215,732` payload bytes
- lightweight artifact: `9906859658`
- artifact contains provenance with `UNPAPER_VERSION=6.1` and `PNGQUANT_VERSION=2.17.0`
- the multi-gigabyte ZIP itself was not uploaded, by design.

## Active candidate — package-local conversion fonts

Pinned Stirling 2.14.3 installs the following Linux font packages in its normal runtime image:

- DejaVu;
- Liberation 2;
- Carlito and Caladea;
- Noto core / mono / extra;
- Noto CJK;
- GNU FreeFont;
- Terminus.

The same Dockerfile later removes non-Regular Noto weights to save roughly 370 MB. The accepted official LibreOffice 26.2.5 Windows runtime already ships its own conversion-font baseline, including Carlito, Caladea, DejaVu and Liberation families. LibreOffice's own source notes that it does not have bundled CJK fonts for its CJK tests, so the Windows portable gap is CJK rather than the complete Linux font stack.

PDF_Tunner therefore keeps the accepted LibreOffice payload and adds only five regular regional Noto Sans CJK subsets from the pinned upstream `notofonts/noto-cjk` tag **`Sans2.004`**:

| Family | File | SHA-256 |
| --- | --- | --- |
| Noto Sans SC | `NotoSansSC-Regular.otf` | `faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9` |
| Noto Sans TC | `NotoSansTC-Regular.otf` | `5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537` |
| Noto Sans HK | `NotoSansHK-Regular.otf` | `8a43afea92bb58dfd9027bd7ac6f5b0b2662e2ffb3e7c1edc02c62b2b21924f1` |
| Noto Sans JP | `NotoSansJP-Regular.otf` | `dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073` |
| Noto Sans KR | `NotoSansKR-Regular.otf` | `69975a0ac8472717870aefeab0a4d52739308d90856b9955313b2ad5e0148d68` |

They are staged directly into `tools/libreoffice/share/fonts/truetype/`, so LibreOffice sees them from the portable tree without host installation. Metadata is kept under `tools/fonts/`.

Candidate validation requires:

1. exact SHA-256 for every downloaded CJK font;
2. proof that LibreOffice's packaged Carlito/Caladea/DejaVu/Liberation baseline is present before adding anything;
3. no matching CJK font files in Windows system/user font directories during the gate;
4. direct package-local LibreOffice DOCX→PDF with SC/TC/HK/JP/KR text;
5. package-local Poppler `pdffonts` proof that all requested CJK families and Latin baseline are embedded;
6. package-local `pdftotext` proof that the CJK text survives conversion;
7. relocation to normal Windows paths containing spaces;
8. when the backend is live, the real Stirling Office→PDF API route must preserve the same CJK font/text contract;
9. all previously accepted gates remain enabled.

`fonts-freefont-ttf` and `fonts-terminus` are present in Stirling's Linux Docker dependency list but are not named by a Stirling source dependency probe or feature gate. They remain documented Linux fallback packages rather than a justification for copying the whole Linux font stack into Windows. The candidate is deliberately tested on real document conversion rather than inferred from package names.

To minimize regression risk, the accepted LibreOffice prepare/validation implementations are preserved byte-for-byte as `prepare-libreoffice-core.ps1` and `validate-libreoffice-core.ps1`. The original workflow entry filenames become narrow wrappers that run the accepted core and then the conversion-font auxiliary scripts.

### Run #100 — localized staging failure

Run #100 (`33791580636`), job `100769194852`, commit `6b88a09cbd0ba286ca67c5378257171e17fd2931`, passed all primary steps through packaged Python/OCRmyPDF/NumPy validation and failed at step 32, `Stage LibreOffice portable runtime and native unoconvert shim`. That workflow entry first executes the byte-for-byte accepted LibreOffice preparation core and only then invokes `prepare-conversion-fonts.ps1`, so the failure is localized to the newly added staging path unless later evidence proves otherwise.

The standard bounded artifact `9908663674` is `12,320` bytes, digest `sha256:15ae6e6230fdb0648222a1ed6c9b7601347430111ac207e6e6d077d807d25c88`, and did not contain the new preparer's stderr. The five pinned Noto Sans CJK 2.004 Regular SHA-256 values were independently rechecked after the failure and remain correct; do not change authenticated hashes merely to make CI pass.

The narrow LibreOffice wrapper now captures only conversion-font preparation failures to `data/logs/conversion-fonts-diagnostic.log`, including exception type/message, PowerShell error ID/category, source script/line/offset, position message, stack trace and formatted error record, then rethrows. Existing bounded failure collection will retain that small log. The accepted `prepare-libreoffice-core.ps1` remains untouched, and no functional gate is weakened.

## Portable architecture

Portable mode activates when `PDF_TUNNER_PORTABLE` exists beside `PDF_Tunner.exe`.

Key package-relative paths:

- backend config/logs/working state → `data/`
- Java temp → `data/tmp/`
- WebView2 profile → `data/webview2/`
- Tauri logs/store/cookies/window state → `data/tauri/...`
- ImageMagick → `tools/imagemagick/`
- Tesseract → `tools/tesseract/`, models → `tools/tesseract/tessdata/`
- Python/OCRmyPDF/NumPy/OpenCV → `tools/python/`
- LibreOffice → `tools/libreoffice/`; `unoconvert.exe` → `tools/bin/`
- conversion fonts → `tools/libreoffice/share/fonts/truetype/`; provenance → `tools/fonts/`
- Poppler → `tools/poppler/Library/bin/`
- WeasyPrint → `tools/weasyprint/`; literal shim → `tools/bin/weasyprint.exe`
- Calibre → `tools/calibre/`; literal launcher → `tools/bin/ebook-convert.exe`
- OCRmyPDF auxiliaries → `tools/bin/unpaper.exe` + sibling DLLs and `tools/bin/pngquant.exe`

Portable mode skips runtime `pdf-tunner://` protocol registration. Primary CI rejects new tracked host AppData/TEMP/registry state and package-local orphan processes.

## Validation and CI policy

Primary workflow: `.github/workflows/pdf-tunner-windows-portable.yml`.

A dependency is accepted only when the **complete current primary workflow** is green with every earlier accepted gate enabled. Version output alone is never sufficient: validate source/hash, package-first isolation, real operation, relocation where practical, backend behavior where applicable, state/process containment and the final assembled package.

Heavy CI uses branch-scoped concurrency with `cancel-in-progress: true`. Do not launch redundant complete regressions. Ordinary CI builds and validates the portable ZIP but uploads only lightweight evidence; the multi-gigabyte ZIP itself is reserved for the final Release after all v1 gates and explicit user authorization.

## Remaining v1 roadmap

### A. External toolchain

1. **conversion fonts** — active candidate;
2. explicit VeraPDF E2E;
3. investigate/build/package `jbig2enc` if technically viable;
4. viable portable RAR/CBR support or a concrete documented limitation;
5. any further exact dependency exposed by the pinned-source parity audit.

### B. Functional validation

Representative E2E must cover OCR, Office↔PDF, HTML/URL/base-URL/EML, WeasyPrint, Poppler, Calibre/eBook, Python/NumPy/OpenCV, qpdf/Ghostscript/ImageMagick/Tesseract/OCRmyPDF, conversion fonts, and RAR/CBR or jbig2enc if integrated. Tests must prove runner-installed software is not satisfying package gates.

### C. Release readiness

1. non-Enterprise parity audit against pinned Stirling 2.14.3;
2. final branding audit;
3. final portability/state/process audit;
4. remove retired diagnostic/integration mechanisms;
5. final downstream diff/output hygiene;
6. final README/AGENTS/provenance/version/hash record;
7. integrate to `main` without reopening old PR #1;
8. publish the clean v1 ZIP only when all gates are complete and explicitly authorized;
9. manual clean-machine Windows 10/11 checklist.

## Compact handoff

- Latest accepted regression: **Run #99 `33786563784`**, job `100752651171`, commit `8d4d3906f6535c5a0e214cf96948e19de0678a23`.
- Newly accepted: **unpaper 6.1 + pngquant 2.17.0**.
- Active candidate: **conversion fonts**, adding only pinned Noto Sans CJK 2.004 Regular regional subsets while retaining and validating LibreOffice's packaged Latin baseline.
- Failed candidate evidence: **Run #100 `33791580636`**, job `100769194852`, failed at the new LibreOffice-wrapper staging step after steps 1–31 were green; artifact `9908663674` lacked the auxiliary exception, so bounded wrapper-level capture is now enabled.
- Next useful complete run must expose the exact staging exception if it still fails; if green, conversion fonts can be accepted and work moves to **explicit VeraPDF E2E**.
