# PDF_Tunner — Release Readiness Status

Status as of 2026-10-08: **Run #132 automated validation accepted; new Windows x64 ZIP candidate retained for one day. Windows 10 VM manual acceptance and final release authorization remain outstanding.** No published v1 Release.

## Immutable basis and accepted build

- Upstream: Stirling PDF **2.14.3**, commit `7fb29d002dbb8fa4b5945d1d1fe8dd164a9f7632`.
- Current automated-accepted candidate: development commit `d60587d28304c32c5efc9aa263e2af6628493665`, primary **Run #132** `37781952129`, job `113326983968`; complete workflow passed, including targeted host-boundary audit. Historical Run #128 was also green but is superseded by this candidate.
- Validated test package: `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip` (temporarily retained as exceptional one-day Actions artifact **#11554603294** for Windows 10 acceptance; **not a published Release**).
- ZIP SHA-256 (Run #132): `D2F93495018DD2BC8A362D33F3335649A721235EFE0FE007AD2DDDEDE39896EB`.
- ZIP size (Run #132): `1,916,053,447` bytes. Earlier Run #128 uncompressed layout: `31,643` files / `4,399,867,226` bytes (do not attribute this layout to #132 without checking its evidence).
- Lightweight CI evidence artifact (Run #132): `11554831945`, 7,853 bytes, digest `sha256:12d15845e9160134327bff9e988c0c71332b26e6ee4edf9fb52fb8fc5eb90b17`. Audit report artifact: `11554457335`.
- Run #127 (`37643235516`) failed because a branding gate inspected the backend-only JAR as though it contained the embedded Tauri React frontend. Run #128 accepted the corrected two-artifact gate and the backend-only asset copy. Retired OCRmyPDF candidate workflow was removed.
- `main` remains the unchanged pinned upstream commit. Do not integrate, tag or publish until readiness decisions are complete.

## Automated acceptance — completed

- [x] Exact upstream/commit identity, Tauri/Cargo tests, Windows executable, backend-only JAR and packaged frontend.
- [x] Brand identity on Windows executable, React/Tauri frontend, API/mobile backend and signature raster assets.
- [x] Embedded/package-first JRE, Fixed WebView2, OCR, Office, PDF converters, OCRmyPDF, Python, image tools, provenance/hashes, representative real API E2E, ZIP integrity.
- [x] Portable state/process containment, shutdown, restored window geometry on second launch, relative-path relocation and no leaked RAR probe/WebView2 installer.
- [x] Repository diff hygiene: no committed build ZIPs/EXEs/logs; the retired focused OCRmyPDF workflow is absent; remaining helper scripts are invoked by active workflows.
- [x] Non-Enterprise external/embedded dependency parity audit against pinned Stirling 2.14.3, subject to documented limitations below.

## Candidate ZIP delivery — Run #129 accepted and temporarily available

- **Run #129** `37754829944`, job `113236699098`, commit `804cd9950f71a6aaa4db9572ca2276e8080958aa`, complete primary regression **SUCCESS**, including exceptional upload.
- **[Download complete PDF_Tunner Windows x64 ZIP (artifact #11541921231)](https://github.com/WillsitoGG/PDF_Tunner/actions/runs/37754829944/artifacts/11541921231)**. Original file: `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`, size **1,916,065,686 bytes**.
- **Run #129 actual ZIP SHA-256: `5ABDEE66382A04BE063CD19BB7C8A40C844CB143A778E048D78D9891433EF95C`**. The original ZIP's digest agrees exactly with the published GitHub Actions artifact digest because `archive: false` preserves the original bytes.
- GitHub artifact `11541921231` expires **2026-10-09 09:53:21 UTC / 11:53:21 Madrid**. Save a local copy before expiry; this is a temporary CI artifact, **not a final Release**.
- Accompanying evidence artifact **#11541945715**, digest `sha256:2d133a638c83e24a9c18c968b375d6c76798fa6dc51d4849793c0e13ce085266`, size **7,855 bytes**, confirms `31,643` files / `4,399,867,226` uncompressed bytes. Distinguish it from the application ZIP.
- On Windows, open **PowerShell** and verify the downloaded ZIP with `(Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\ruta\al\PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip').Hash`. The result **must equal** `5ABDEE66382A04BE063CD19BB7C8A40C844CB143A778E048D78D9891433EF95C`.
- This delivery does **not** complete the mandatory manual tests below; users must report their results. No main integration or final Release without the remaining acceptance and authorization.

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

## Windows 10 VM issues still pending acceptance (2026-10-08)

Source-only regression-fix branch addresses Stirling branding/search and official update checks, local PAYG 404, and default-association prompting. No accepted build yet; Windows GUI QA Run #2 failed at the CDP harness after starting the real binary. Follow-up: audit network + host filesystem/registry, then one full CI, then fresh VM tests. Disk-footprint optimization deferred.


## Boundary audit and user Windows 10 retest (2026-10-08; PENDING)

A new scoped host-boundary process/TCP and AppData/registry audit gate will run before the ZIP candidate is uploaded. Its limits are explicit; broader per-process Windows 10 VM tracing remains unverified. Disk-space optimization deferred. No Release published.


## Run #131 harness defect and early regression guard (2026-10-08)

Run #131 failed at host-audit script: `DirectoryInfo.Length` under strict PowerShell, before actual observation. The fix uses a directory sentinel and introduces a cheap pre-compilation `-SelfTest` plus syntax preflight for the actual script. Host containment audit, ZIP and clean Windows 10 VM testing remain pending. Never infer sandbox compliance from this fix.


### Run #132 final Windows CI acceptance and manual handoff (2026-10-08)

The complete Windows x64 portable pipeline **Run #132 attempt 1** (`37781952129`, job `113326983968`, commit `d60587d28304c32c5efc9aa263e2af6628493665`) is **green**. It passed the early host-audit self-test, Tauri/Rust build, real Java/backend/converter/OCR tests, frontend/backend branding checks, package-local dependencies, portable shutdown and second-launch window restore, and the scoped native host-boundary gate. During the 45-second host audit the log reported **6 sampled TCP connections, 0 external connections, 0 changes in watched AppData/TEMP product paths, 0 changes in watched HKCU registry keys; graceful shutdown**. This **does not** prove kernel-level sandbox confinement or the absence of short-lived writes, unsampled traffic, DNS/UDP, or unintended host changes outside the watched locations.

Exceptional **Windows 10 VM candidate ZIP** (not final Release): Actions Run #132 artifact **11554603294**, file `PDF_Tunner-2.14.3-bootstrap-Windows-x64-Portable.zip`, exactly **1,916,053,447 bytes** and SHA-256 **`D2F93495018DD2BC8A362D33F3335649A721235EFE0FE007AD2DDDEDE39896EB`**. Artifact expiry: **2026-10-09 13:48:53 UTC** (15:48:53 Europe/Madrid). Lightweight CI evidence artifact **11554831945**, 7,853 bytes (expires 2026-10-15). Scoped audit JSON artifact **11554457335**, 608 bytes (expires 2026-10-11). Artifacts: https://github.com/WillsitoGG/PDF_Tunner/actions/runs/37781952129 . Do not archive this temporary Actions ZIP as a historical Release.

**Remaining before publication**: clean Windows 10 VM manual run of **this exact SHA-verified ZIP** (do not overwrite old Run #129 folder), screenshots of light/dark PDF_Tunner interface/search and no Stirling update popup, no generic network/PAYG 404 toasts, real offline PDF operations, relocation/relaunch, saved state, local caches/logs and per-process filesystem/registry trace when needed. The old Windows Server GUI automation via WebView2 CDP was inconclusive and is not a substitute. Preserve no-Release/no-`main`-merge policy until user confirms VM acceptance. Package footprint optimization deferred to last phase.
