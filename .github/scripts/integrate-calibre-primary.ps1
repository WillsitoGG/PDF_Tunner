[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ExpectedDevHead,
  [string]$DevBranch = 'pdf-tunner/windows-portable-v1',
  [string]$CandidateBranch = 'pdf-tunner/calibre-candidate'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Replace-One {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$Old,
    [Parameter(Mandatory = $true)][string]$New,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $count = [regex]::Matches($Text, [regex]::Escape($Old)).Count
  if ($count -ne 1) { throw "Expected exactly one '$Label' anchor, found $count." }
  return $Text.Replace($Old, $New)
}

$candidateHead = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($candidateHead)) { throw 'Cannot resolve candidate HEAD.' }

& git fetch origin "+refs/heads/$DevBranch`:refs/remotes/origin/$DevBranch"
if ($LASTEXITCODE -ne 0) { throw 'Failed to fetch primary development branch.' }
$remoteDev = (& git rev-parse "refs/remotes/origin/$DevBranch").Trim()
if ($remoteDev -ne $ExpectedDevHead) {
  throw "Primary development branch moved unexpectedly. Expected $ExpectedDevHead, got $remoteDev."
}

& git checkout -B $DevBranch "refs/remotes/origin/$DevBranch"
if ($LASTEXITCODE -ne 0) { throw 'Failed to check out primary development branch.' }

$carry = @(
  '.github/scripts/calibre-launcher.rs',
  '.github/scripts/prepare-calibre.ps1',
  '.github/scripts/validate-calibre.ps1',
  'README.md',
  'AGENTS.md'
)
& git checkout $candidateHead -- $carry
if ($LASTEXITCODE -ne 0) { throw 'Failed to copy permanent Calibre candidate files into primary development branch.' }

$workflowPath = '.github/workflows/pdf-tunner-windows-portable.yml'
$workflow = (Get-Content -LiteralPath $workflowPath -Raw) -replace "`r`n", "`n"

$workflow = Replace-One $workflow @'
  PDF_TUNNER_LIBREOFFICE_MSI_SHA256: "f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9"
  CI: "true"
'@ @'
  PDF_TUNNER_LIBREOFFICE_MSI_SHA256: "f15ba07bfcb0186986cf3171063506f5d207c11f8cc051ba0d135209e9e915f9"
  PDF_TUNNER_CALIBRE_VERSION: "9.14.0"
  PDF_TUNNER_CALIBRE_MSI_URL: "https://download.calibre-ebook.com/9.14.0/calibre-64bit-9.14.0.msi"
  PDF_TUNNER_CALIBRE_MSI_SHA256: "4ccaf2a49a0069b5e78291ee7248dcd8967896d316d6432ddf657b6feae8f32d"
  CI: "true"
'@ 'Calibre env pins'

$workflow = Replace-One $workflow @'
            './.github/scripts/prepare-weasyprint.ps1',
            './.github/scripts/validate-weasyprint.ps1'
'@ @'
            './.github/scripts/prepare-weasyprint.ps1',
            './.github/scripts/validate-weasyprint.ps1',
            './.github/scripts/prepare-calibre.ps1',
            './.github/scripts/validate-calibre.ps1'
'@ 'Calibre PowerShell preflight'

$workflow = Replace-One $workflow @'
          foreach ($source in @('./.github/scripts/unoconvert-launcher.rs', './.github/scripts/weasyprint-launcher.rs')) {
'@ @'
          foreach ($source in @('./.github/scripts/unoconvert-launcher.rs', './.github/scripts/weasyprint-launcher.rs', './.github/scripts/calibre-launcher.rs')) {
'@ 'Calibre Rust preflight'

$calibreStage = @'
      - name: Stage official Calibre Windows x64 runtime and portable launcher
        shell: pwsh
        run: |
          & './.github/scripts/prepare-calibre.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -CalibreVersion $env:PDF_TUNNER_CALIBRE_VERSION `
            -CalibreMsiUrl $env:PDF_TUNNER_CALIBRE_MSI_URL `
            -CalibreMsiSha256 $env:PDF_TUNNER_CALIBRE_MSI_SHA256 `
            -LauncherSource './.github/scripts/calibre-launcher.rs'

      - name: Validate packaged Calibre independently of runner PATH
        shell: pwsh
        run: |
          & './.github/scripts/validate-calibre.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -CalibreVersion $env:PDF_TUNNER_CALIBRE_VERSION `
            -CalibreMsiSha256 $env:PDF_TUNNER_CALIBRE_MSI_SHA256 `
            -RequireRelocation

'@
$workflow = Replace-One $workflow "      - name: Stage official WeasyPrint Windows runtime and portable shim`n" ($calibreStage + "      - name: Stage official WeasyPrint Windows runtime and portable shim`n") 'Calibre staging steps'

$workflow = Replace-One $workflow @'
            (Join-Path $portable 'tools/poppler/Library/bin'),
            (Join-Path $portable 'tools/imagemagick'),
'@ @'
            (Join-Path $portable 'tools/poppler/Library/bin'),
            (Join-Path $portable 'tools/calibre'),
            (Join-Path $portable 'tools/imagemagick'),
'@ 'backend package-only Calibre PATH'

$calibreBackend = @'
          & './.github/scripts/validate-calibre.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -CalibreVersion $env:PDF_TUNNER_CALIBRE_VERSION `
            -CalibreMsiSha256 $env:PDF_TUNNER_CALIBRE_MSI_SHA256 `
            -BackendBaseUrl "http://127.0.0.1:$port" `
            -BackendLogRoot (Join-Path $portable 'data')

'@
$backendAnchor = @'
          & './.github/scripts/validate-weasyprint.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -Version $env:PDF_TUNNER_WEASYPRINT_VERSION `
            -ExpectedArchiveSha256 $env:PDF_TUNNER_WEASYPRINT_SHA256 `
            -BackendBaseUrl "http://127.0.0.1:$port" `
            -BackendLogRoot (Join-Path $portable 'data')
'@
$workflow = Replace-One $workflow $backendAnchor ($calibreBackend + $backendAnchor) 'live Stirling Calibre validation'

$workflow = Replace-One $workflow @'
            'tools/poppler/VERSION.txt',
            'tools/weasyprint/weasyprint.exe',
'@ @'
            'tools/poppler/VERSION.txt',
            'tools/calibre/ebook-convert.exe',
            'tools/calibre/PROVENANCE.txt',
            'tools/calibre/SHA256SUMS.txt',
            'tools/calibre/VERSION.txt',
            'tools/bin/ebook-convert.exe',
            'tools/bin/CALIBRE_PROVENANCE.txt',
            'tools/weasyprint/weasyprint.exe',
'@ 'final Calibre layout requirements'

$cleanupAnchor = @'
          & './.github/scripts/validate-libreoffice.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -LibreOfficeVersion $env:PDF_TUNNER_LIBREOFFICE_VERSION `
            -LibreOfficeMsiSha256 $env:PDF_TUNNER_LIBREOFFICE_MSI_SHA256

          Remove-Item -LiteralPath $data -Recurse -Force -ErrorAction Stop
'@
$calibreCleanup = @'
          & './.github/scripts/validate-libreoffice.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -LibreOfficeVersion $env:PDF_TUNNER_LIBREOFFICE_VERSION `
            -LibreOfficeMsiSha256 $env:PDF_TUNNER_LIBREOFFICE_MSI_SHA256

          & './.github/scripts/validate-calibre.ps1' `
            -PortableRoot './dist/PDF_Tunner' `
            -CalibreVersion $env:PDF_TUNNER_CALIBRE_VERSION `
            -CalibreMsiSha256 $env:PDF_TUNNER_CALIBRE_MSI_SHA256

          Remove-Item -LiteralPath $data -Recurse -Force -ErrorAction Stop
'@
$workflow = Replace-One $workflow $cleanupAnchor $calibreCleanup 'final Calibre package validation at unique cleanup boundary'

$workflow = Replace-One $workflow @'
            "POPPLER_ARCHIVE_SHA256=$env:PDF_TUNNER_POPPLER_SHA256",
            "WEASYPRINT_VERSION=$env:PDF_TUNNER_WEASYPRINT_VERSION",
'@ @'
            "POPPLER_ARCHIVE_SHA256=$env:PDF_TUNNER_POPPLER_SHA256",
            "CALIBRE_VERSION=$env:PDF_TUNNER_CALIBRE_VERSION",
            "CALIBRE_MSI_SHA256=$env:PDF_TUNNER_CALIBRE_MSI_SHA256",
            "WEASYPRINT_VERSION=$env:PDF_TUNNER_WEASYPRINT_VERSION",
'@ 'Calibre lightweight evidence metadata'

$workflow = Replace-One $workflow @'
          Copy-Item -LiteralPath './dist/PDF_Tunner/tools/poppler/SHA256SUMS.txt' -Destination (Join-Path $evidence 'POPPLER_SHA256SUMS.txt') -Force
          Copy-Item -LiteralPath './dist/PDF_Tunner/tools/weasyprint/PROVENANCE.txt' -Destination (Join-Path $evidence 'WEASYPRINT_PROVENANCE.txt') -Force
'@ @'
          Copy-Item -LiteralPath './dist/PDF_Tunner/tools/poppler/SHA256SUMS.txt' -Destination (Join-Path $evidence 'POPPLER_SHA256SUMS.txt') -Force
          Copy-Item -LiteralPath './dist/PDF_Tunner/tools/calibre/PROVENANCE.txt' -Destination (Join-Path $evidence 'CALIBRE_PROVENANCE.txt') -Force
          Copy-Item -LiteralPath './dist/PDF_Tunner/tools/calibre/SHA256SUMS.txt' -Destination (Join-Path $evidence 'CALIBRE_SHA256SUMS.txt') -Force
          Copy-Item -LiteralPath './dist/PDF_Tunner/tools/bin/CALIBRE_PROVENANCE.txt' -Destination (Join-Path $evidence 'CALIBRE_SHIM_PROVENANCE.txt') -Force
          Copy-Item -LiteralPath './dist/PDF_Tunner/tools/weasyprint/PROVENANCE.txt' -Destination (Join-Path $evidence 'WEASYPRINT_PROVENANCE.txt') -Force
'@ 'Calibre lightweight evidence files'

[System.IO.File]::WriteAllText((Resolve-Path $workflowPath).Path, $workflow, [System.Text.UTF8Encoding]::new($false))

$diagPath = '.github/scripts/collect-startup-diagnostics.ps1'
$diag = (Get-Content -LiteralPath $diagPath -Raw) -replace "`r`n", "`n"
$diag = Replace-One $diag @'
$hostProfilePaths = @(
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner\EBWebView'),
    (Join-Path $env:APPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:APPDATA 'Stirling-PDF')
)
'@ @'
$hostProfilePaths = @(
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner\EBWebView'),
    (Join-Path $env:APPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:APPDATA 'Stirling-PDF'),
    (Join-Path $env:APPDATA 'calibre'),
    (Join-Path $env:LOCALAPPDATA 'calibre'),
    (Join-Path $env:LOCALAPPDATA 'calibre-cache')
)
'@ 'Calibre host-profile diagnostics block'
$diag = Replace-One $diag "'(?i)pdf.?tunner|stirling|willsitogg|pdf-tunner'" "'(?i)pdf.?tunner|stirling|willsitogg|pdf-tunner|calibre'" 'Calibre host inventory filter'
$diag = Replace-One $diag "'(?i)PDF_Tunner|java|msedgewebview2|weasyprint'" "'(?i)PDF_Tunner|java|msedgewebview2|weasyprint|ebook-convert|calibre'" 'Calibre process-name diagnostics'
$diag = Replace-One $diag "'(?i)PDF_Tunner|Stirling|webview2|weasyprint'" "'(?i)PDF_Tunner|Stirling|webview2|weasyprint|ebook-convert|calibre'" 'Calibre process-command diagnostics'
[System.IO.File]::WriteAllText((Resolve-Path $diagPath).Path, $diag, [System.Text.UTF8Encoding]::new($false))

$requiredWorkflowTokens = @(
  'PDF_TUNNER_CALIBRE_VERSION: "9.14.0"',
  'Stage official Calibre Windows x64 runtime and portable launcher',
  'Validate packaged Calibre independently of runner PATH',
  '-BackendBaseUrl "http://127.0.0.1:$port"',
  "'tools/calibre/ebook-convert.exe'",
  'CALIBRE_MSI_SHA256=$env:PDF_TUNNER_CALIBRE_MSI_SHA256',
  'CALIBRE_PROVENANCE.txt'
)
$finalWorkflow = Get-Content -LiteralPath $workflowPath -Raw
foreach ($token in $requiredWorkflowTokens) {
  if ($finalWorkflow -notlike "*$token*") { throw "Primary workflow integration guard missing token: $token" }
}
& git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed.' }

# Preserve the exact generated files outside .github/workflows so the ordinary
# Actions token can publish them. The connector will reuse these exact blob
# objects at their permanent paths in one atomic development-branch commit.
$snapshotWorkflow = Join-Path $env:RUNNER_TEMP 'calibre-primary-workflow.snapshot.yml'
$snapshotDiag = Join-Path $env:RUNNER_TEMP 'calibre-startup-diagnostics.snapshot.ps1'
Copy-Item -LiteralPath $workflowPath -Destination $snapshotWorkflow -Force
Copy-Item -LiteralPath $diagPath -Destination $snapshotDiag -Force
$workflowHash = (Get-FileHash -LiteralPath $snapshotWorkflow -Algorithm SHA256).Hash
$diagHash = (Get-FileHash -LiteralPath $snapshotDiag -Algorithm SHA256).Hash
Write-Host "Generated primary workflow SHA-256: $workflowHash"
Write-Host "Generated diagnostics SHA-256: $diagHash"

& git checkout -B $CandidateBranch $candidateHead
if ($LASTEXITCODE -ne 0) { throw 'Failed to return to candidate branch for snapshot publication.' }
$snapshotRoot = '.github/generated/calibre-primary'
New-Item -ItemType Directory -Force -Path $snapshotRoot | Out-Null
Copy-Item -LiteralPath $snapshotWorkflow -Destination (Join-Path $snapshotRoot 'pdf-tunner-windows-portable.yml.snapshot') -Force
Copy-Item -LiteralPath $snapshotDiag -Destination (Join-Path $snapshotRoot 'collect-startup-diagnostics.ps1.snapshot') -Force
$note = "Snapshot generation Run $env:GITHUB_RUN_ID produced deterministic primary workflow/diagnostics blobs after all integration guards passed; Actions cannot push workflow-path changes, so the GitHub connector will promote these exact blobs."
Add-Content -LiteralPath 'README.md' -Encoding utf8 -Value "`n<!-- $note -->"
Add-Content -LiteralPath 'AGENTS.md' -Encoding utf8 -Value "`n- **2026-09-03:** $note"

& git config user.name 'Willsito'
& git config user.email 'g.fernandez.garcia@outlook.es'
& git add -- $snapshotRoot 'README.md' 'AGENTS.md'
& git commit -m 'chore(ci): stage Calibre primary snapshots [skip ci]' -m "Store exact generated workflow and startup-diagnostics snapshots after all integration guards pass. Workflow SHA-256: $workflowHash. Diagnostics SHA-256: $diagHash. These files are temporary transport objects for the connector and are not part of the permanent development tree."
if ($LASTEXITCODE -ne 0) { throw 'Failed to create candidate snapshot commit.' }
$newCandidateHead = (& git rev-parse HEAD).Trim()
& git push origin "HEAD:refs/heads/$CandidateBranch"
if ($LASTEXITCODE -ne 0) { throw 'Failed to publish candidate snapshot commit.' }
Write-Host "PASS: published deterministic Calibre primary snapshots at candidate commit $newCandidateHead."
