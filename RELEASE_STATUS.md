# PDF_Tunner — Release Readiness Status

Status as of 2026-10-08: **automated candidate accepted; clean-machine validation and release authorization outstanding.** This is not a published v1 release.

## Immutable basis and accepted build

- Upstream: Stirling PDF **2.14.3**, commit `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`.
- Current accepted functional candidate: development commit `4f1895abccd399434b5d1d2ef6711ccae9d1db43`, primary **Run #128** `37647274558`, job `112881213154`; all primary steps completed successfully, including product branding, real backend functions, package-local dependencies, portable process/state isolation and second launch.
- Validated package: `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip` (generated and verified during CI; **not retained as an ordinary CI download or Release asset**).
- ZIP SHA-256: `7F5D5A4A90618097233529F6E2A12CDA8F5167FAE83552789333611C2C0B9078`.
- ZIP size: `1,916,067,291` bytes; uncompressed portable payload: `31,643` files / `4,399,867,226` bytes.
- Lightweight evidence artifact: `11497516286`, 7,853 bytes, digest `sha256:348dfb6a024b9a129bf80d289cda4cc2e2daedc7d3c03a5cc5433552eafacd1d`.
- Run #127 (`37643235516`) failed because a branding gate inspected the backend-only JAR as though it contained the embedded Tauri React frontend. Run #128 accepted the corrected two-artifact gate and the backend-only asset copy. Retired OCRmyPDF candidate workflow was removed.
- `main` remains the unchanged pinned upstream commit. Do not integrate, tag or publish until readiness decisions are complete.

## Automated acceptance — completed

- [x] Exact upstream/commit identity, Tauri/Cargo tests, Windows executable, backend-only JAR and packaged frontend.
- [x] Brand identity on Windows executable, React/Tauri frontend, API/mobile backend and signature raster assets.
- [x] Embedded/package-first JRE, Fixed WebView2, OCR, Office, PDF converters, OCRmyPDF, Python, image tools, provenance/hashes, representative real API E2E, ZIP integrity.
- [x] Portable state/process containment, shutdown, restored window geometry on second launch, relative-path relocation and no leaked RAR probe/WebView2 installer.
- [x] Repository diff hygiene: no committed build ZIPs/EXEs/logs; the retired focused OCRmyPDF workflow is absent; remaining helper scripts are invoked by active workflows.
- [x] Non-Enterprise external/embedded dependency parity audit against pinned Stirling 2.14.3, subject to documented limitations below.

## Candidate ZIP delivery — pending one opt-in CI run

- The primary workflow supports an explicit `workflow_dispatch` input `retain_candidate_zip=true` or a deliberate push commit subject containing `[deliver-portable-candidate]`. All ordinary runs still upload only lightweight evidence.
- The next delivery commit uses the latter opt-in once to generate and validate the full portable ZIP with the same accepted primary regression, then uploads the **actual single ZIP file** using `actions/upload-artifact@v7.0.1`, `archive: false`, `retention-days: 1`, and error-on-missing. This is an exceptional one-day testing artifact, **not a published Release**.
- The package will be downloadable from that run's **Artifacts** section after the job completes. Record its *new* ZIP SHA-256, size, Run/job, commit and artifact identity from that run before testing; the earlier Run #128 hash is historical and cannot be assumed identical after a rebuild.
- Since the GitHub connector cannot read account-specific Actions storage billing/quota, check the upload's terminal result. If GitHub rejects the ~1.9 GB artifact for storage limits, do not repeatedly rebuild/upload blindly; use another approved delivery route instead.
- Once downloaded, immediately save a local copy and verify on Windows PowerShell: `(Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\path\to\PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip').Hash`. Compare it with the SHA recorded by the same candidate run.
- Manual testing remains **not performed** until the user runs and reports the checks below.

## Manual acceptance — NOT YET PERFORMED

A **separate, authorized delivery of the actual candidate ZIP** is needed before running this checklist. Do not confuse the lightweight CI evidence ZIP with the portable application. Test Windows 10 x64 and Windows 11 x64 in fresh/isolated environments, ideally without system-wide Java/Python/LibreOffice/Tesseract or an Evergreen WebView2 installation:

- [ ] Confirm the candidate ZIP SHA-256 matches the approved build evidence; extract to a writable location with **spaces and non-ASCII characters** in its path; start `PDF_Tunner.exe` without an installer or admin elevation.
- [ ] With the network unavailable after ZIP acquisition, verify the embedded Fixed WebView2 and local backend start successfully, with all expected non-Enterprise tools visible and no external dependency prompts.
- [ ] Exercise representative end-user UI flows: open/view, reorder/merge/split, annotate/sign, OCR (Spanish + English), Office→PDF, PDF→DOCX/PPTX, PDF→CSV/XLSX, EML→PDF, image/eBook conversions, and PDF/A validation where supported.
- [ ] Close and relaunch; confirm remembered window position/size, saved settings and clean termination of child processes. Confirm caches/logs/temp reside in the portable tree wherever technically possible, with no unexpected AppData/registry persistence.
- [ ] Move or rename the extracted folder and repeat startup plus a conversion. Check no absolute-path dependency on the original location; delete the extracted tree after exit without locked files.
- [ ] Confirm that PDF→CBR needs a legitimately user-supplied `tools/rar/rar.exe`; CBR→PDF works without it. Do not ship `rar.exe` or fake RAR data.
- [ ] Record OS builds, hardware, SHA-256, passed/failed operations and any persistence exceptions. Resolve confirmed failures before main integration/release.

## Explicit limits and release gate

- Upstream URL→PDF remains disabled by default for security; do not enable solely for parity. Upstream FFmpeg/PDF-to-video path is disabled; no undocumented activation.
- Exact commercial RAR creation requires a separately licensed encoder supplied by the user. Other non-Enterprise features remain subject to their upstream feature/config semantics.
- **Do not publish a GitHub Release without the user's explicit authorization.** A candidate transport needed for clean-machine testing must be chosen deliberately, with minimal retention/storage impact and clear SHA verification.
- Following manual acceptance: perform final diff and license/provenance review, update README + AGENTS + this status together, integrate to `main` using a new PR (never PR #1), and publish a single clean Windows x64 portable ZIP as a Release asset only when separately authorized.
