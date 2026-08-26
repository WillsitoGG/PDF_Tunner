from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1]).resolve()
expected_head = "dc176ccf38a9f8b4489216119bf648d010e19349"


def run(*args):
    return subprocess.check_output(args, cwd=repo, text=True).strip()


actual_head = run("git", "rev-parse", "HEAD")
if actual_head != expected_head:
    raise SystemExit(
        f"Staging HEAD moved unexpectedly. Expected {expected_head}, got {actual_head}."
    )

workflow = repo / ".github/workflows/pdf-tunner-webview2-fixed-stage.yml"
text = workflow.read_text(encoding="utf-8")

launch_anchor = '''          $process = Start-Process -FilePath $exe -WorkingDirectory $portable -PassThru
          Write-Host "Started PDF_Tunner PID $($process.Id)"

          try {
'''
launch_replacement = '''          $process = Start-Process -FilePath $exe -WorkingDirectory $portable -PassThru
          Write-Host "Started PDF_Tunner PID $($process.Id)"

          $diagnostics = Join-Path $PWD 'dist/webview2-live-diagnostics'
          New-Item -ItemType Directory -Force -Path $diagnostics | Out-Null
          $runtimeRoot = Join-Path $portable 'runtime/webview2/fixed'
          $runtimeExe = Join-Path $runtimeRoot 'msedgewebview2.exe'
          @(
            "PortableRoot=$portable",
            "PDF_Tunner_PID=$($process.Id)",
            "RuntimeRoot=$runtimeRoot",
            "RuntimeExe=$runtimeExe",
            "RuntimeProductVersion=$((Get-Item -LiteralPath $runtimeExe).VersionInfo.ProductVersion)"
          ) | Set-Content -LiteralPath (Join-Path $diagnostics 'launch-context.txt') -Encoding utf8
          foreach ($metadata in @('PROVENANCE.txt', 'version.txt', 'SHA256SUMS.txt')) {
            $source = Join-Path $portable "runtime/webview2/$metadata"
            if (Test-Path -LiteralPath $source -PathType Leaf) {
              Copy-Item -LiteralPath $source -Destination (Join-Path $diagnostics $metadata) -Force
            }
          }
          (& icacls.exe $runtimeRoot 2>&1) | Out-String -Width 4096 |
            Set-Content -LiteralPath (Join-Path $diagnostics 'runtime-icacls-before-launch.txt') -Encoding utf8
          (Get-Acl -LiteralPath $runtimeRoot).Access |
            Format-Table IdentityReference, FileSystemRights, AccessControlType, IsInherited -AutoSize |
            Out-String -Width 4096 |
            Set-Content -LiteralPath (Join-Path $diagnostics 'runtime-acl-before-launch.txt') -Encoding utf8

          try {
'''
if text.count(launch_anchor) != 1:
    raise SystemExit(
        f"Expected exactly one live-launch anchor, found {text.count(launch_anchor)}."
    )
text = text.replace(launch_anchor, launch_replacement)

catch_anchor = '''          }
          finally {
            $process.Refresh()
'''
catch_replacement = '''          }
          catch {
            $caught = $_
            $caught | Format-List * -Force | Out-String -Width 4096 |
              Set-Content -LiteralPath (Join-Path $diagnostics 'exception.txt') -Encoding utf8
            $caught.ScriptStackTrace |
              Set-Content -LiteralPath (Join-Path $diagnostics 'script-stack-trace.txt') -Encoding utf8
            if ($Error.Count -gt 0) {
              $Error[0] | Format-List * -Force | Out-String -Width 4096 |
                Set-Content -LiteralPath (Join-Path $diagnostics 'error-zero.txt') -Encoding utf8
            }
            try {
              $process.Refresh()
              @(
                "HasExited=$($process.HasExited)",
                $(if ($process.HasExited) { "ExitCode=$($process.ExitCode)" } else { 'ExitCode=<running>' })
              ) | Set-Content -LiteralPath (Join-Path $diagnostics 'pdf-tunner-process-state.txt') -Encoding utf8
            }
            catch {
              $_ | Format-List * -Force | Out-String -Width 4096 |
                Set-Content -LiteralPath (Join-Path $diagnostics 'process-state-capture-error.txt') -Encoding utf8
            }
            $bootstrapError = Join-Path $portable 'data/logs/portable-bootstrap-error.log'
            if (Test-Path -LiteralPath $bootstrapError -PathType Leaf) {
              Copy-Item -LiteralPath $bootstrapError -Destination (Join-Path $diagnostics 'portable-bootstrap-error.log') -Force
            }
            $logTails = Join-Path $diagnostics 'portable-log-tails.txt'
            foreach ($log in @(Get-ChildItem -LiteralPath (Join-Path $portable 'data') -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue)) {
              Add-Content -LiteralPath $logTails -Encoding utf8 -Value "=== $($log.FullName) ==="
              Get-Content -LiteralPath $log.FullName -Tail 300 -ErrorAction SilentlyContinue |
                Add-Content -LiteralPath $logTails -Encoding utf8
            }
            Get-CimInstance Win32_Process |
              Where-Object { $_.Name -match 'PDF_Tunner|java|msedgewebview2' -or ($_.CommandLine -and $_.CommandLine -match 'PDF_Tunner|Stirling|webview2') } |
              Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine |
              Format-List | Out-String -Width 4096 |
              Set-Content -LiteralPath (Join-Path $diagnostics 'processes-at-exception.txt') -Encoding utf8
            throw
          }
          finally {
            $process.Refresh()
'''
if text.count(catch_anchor) != 1:
    raise SystemExit(
        f"Expected exactly one live-launch try/finally anchor, found {text.count(catch_anchor)}."
    )
text = text.replace(catch_anchor, catch_replacement)

old_tail = '''      - name: Print diagnostics on failure
        if: failure()
        shell: pwsh
        run: |
          $portable = Join-Path $PWD 'dist/PDF_Tunner'
          $provenance = Join-Path $portable 'runtime/webview2/PROVENANCE.txt'
          if (Test-Path -LiteralPath $provenance) {
            Write-Host '=== Fixed WebView2 provenance ==='
            Get-Content -LiteralPath $provenance
          }
          if (Test-Path -LiteralPath (Join-Path $portable 'data')) {
            Write-Host '=== Portable data/log tree ==='
            Get-ChildItem -LiteralPath (Join-Path $portable 'data') -Recurse -Force -ErrorAction SilentlyContinue | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
          }
          Write-Host '=== Relevant processes ==='
          Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'PDF_Tunner|java|msedgewebview2' -or ($_.CommandLine -and $_.CommandLine -match 'PDF_Tunner|Stirling|webview2') } | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine | Format-List
'''
new_tail = '''      - name: Print diagnostics on failure
        if: failure()
        shell: pwsh
        run: |
          $portable = Join-Path $PWD 'dist/PDF_Tunner'
          $diagnostics = Join-Path $PWD 'dist/webview2-live-diagnostics'
          New-Item -ItemType Directory -Force -Path $diagnostics | Out-Null

          $provenance = Join-Path $portable 'runtime/webview2/PROVENANCE.txt'
          if (Test-Path -LiteralPath $provenance -PathType Leaf) {
            Write-Host '=== Fixed WebView2 provenance ==='
            Get-Content -LiteralPath $provenance
            Copy-Item -LiteralPath $provenance -Destination (Join-Path $diagnostics 'PROVENANCE.txt') -Force
          }
          foreach ($metadata in @('version.txt', 'SHA256SUMS.txt')) {
            $source = Join-Path $portable "runtime/webview2/$metadata"
            if (Test-Path -LiteralPath $source -PathType Leaf) {
              Copy-Item -LiteralPath $source -Destination (Join-Path $diagnostics $metadata) -Force
            }
          }

          $runtimeRoot = Join-Path $portable 'runtime/webview2/fixed'
          if (Test-Path -LiteralPath $runtimeRoot -PathType Container) {
            (& icacls.exe $runtimeRoot 2>&1) | Out-String -Width 4096 |
              Set-Content -LiteralPath (Join-Path $diagnostics 'runtime-icacls-after-failure.txt') -Encoding utf8
            (Get-Acl -LiteralPath $runtimeRoot).Access |
              Format-Table IdentityReference, FileSystemRights, AccessControlType, IsInherited -AutoSize |
              Out-String -Width 4096 |
              Set-Content -LiteralPath (Join-Path $diagnostics 'runtime-acl-after-failure.txt') -Encoding utf8
          }

          $bootstrapError = Join-Path $portable 'data/logs/portable-bootstrap-error.log'
          if (Test-Path -LiteralPath $bootstrapError -PathType Leaf) {
            Copy-Item -LiteralPath $bootstrapError -Destination (Join-Path $diagnostics 'portable-bootstrap-error.log') -Force
          }

          $logTails = Join-Path $diagnostics 'portable-log-tails-after-failure.txt'
          foreach ($log in @(Get-ChildItem -LiteralPath (Join-Path $portable 'data') -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue)) {
            Add-Content -LiteralPath $logTails -Encoding utf8 -Value "=== $($log.FullName) ==="
            Get-Content -LiteralPath $log.FullName -Tail 300 -ErrorAction SilentlyContinue |
              Add-Content -LiteralPath $logTails -Encoding utf8
          }

          if (Test-Path -LiteralPath (Join-Path $portable 'data')) {
            Write-Host '=== Portable data/log tree ==='
            $dataTree = Get-ChildItem -LiteralPath (Join-Path $portable 'data') -Recurse -Force -ErrorAction SilentlyContinue |
              Select-Object FullName, Length, LastWriteTime
            $dataTree | Format-Table -AutoSize
            $dataTree | Format-Table -AutoSize | Out-String -Width 4096 |
              Set-Content -LiteralPath (Join-Path $diagnostics 'portable-data-tree.txt') -Encoding utf8
          }

          Write-Host '=== Relevant processes ==='
          $processes = Get-CimInstance Win32_Process |
            Where-Object { $_.Name -match 'PDF_Tunner|java|msedgewebview2' -or ($_.CommandLine -and $_.CommandLine -match 'PDF_Tunner|Stirling|webview2') } |
            Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine
          $processes | Format-List
          $processes | Format-List | Out-String -Width 4096 |
            Set-Content -LiteralPath (Join-Path $diagnostics 'processes-after-failure.txt') -Encoding utf8

      - name: Upload Fixed WebView2 live diagnostics
        if: failure()
        uses: actions/upload-artifact@v7.0.1
        with:
          name: PDF_Tunner-webview2-live-diagnostics
          path: dist/webview2-live-diagnostics
          if-no-files-found: error
          include-hidden-files: true
          retention-days: 7
'''
if text.count(old_tail) != 1:
    raise SystemExit(f"Expected exactly one diagnostics tail, found {text.count(old_tail)}.")
text = text.replace(old_tail, new_tail)
workflow.write_text(text, encoding="utf-8", newline="\n")

readme = repo / "README.md"
readme_note = '''

### WebView2 live-launch diagnostic — staging Run `32965658540`

Staging Run `32965658540` passed the pinned upstream check, official desktop preparation, Tauri/Cargo tests, production executable build, portable assembly, exact Microsoft Fixed WebView2 CAB download/SHA-256/extraction/normalization, static Fixed Runtime validation and bundled Java 25 validation. Its only failure was the subsequent real-launch gate (`Validate real launch uses package-local Fixed WebView2 and backend`). Because that staging workflow only printed failure diagnostics to the Actions console, the next diagnostic revision persists the live-launch exception/stack trace, bootstrap-error log when present, runtime ACL/metadata, portable log tails and relevant process command lines into a short-lived `PDF_Tunner-webview2-live-diagnostics` Actions artifact. This diagnostic artifact is evidence only and must not become a Release asset.
'''
readme.write_text(readme.read_text(encoding="utf-8") + readme_note, encoding="utf-8", newline="\n")

agents = repo / "AGENTS.md"
agents_note = '''

### Fixed WebView2 live-launch evidence after Run `32965658540`

- Run `32965658540` proves the exact pinned CAB path, SHA-256, extraction/normalization, static runtime validator and bundled Java all pass in the full heavy staging job; do not regress those accepted gates while diagnosing live launch.
- Its sole failure is the real packaged launch/runtime-selection gate. Until that failure is diagnosed, do not promote WebView2 to the primary workflow.
- Staging failure diagnostics must persist the PowerShell exception and script stack trace, `portable-bootstrap-error.log` when present, runtime ACL/metadata, portable log tails and relevant PDF_Tunner/Java/WebView2 process paths/command lines into the short-lived `PDF_Tunner-webview2-live-diagnostics` artifact. Never publish that diagnostic artifact as a Release asset.
'''
agents.write_text(agents.read_text(encoding="utf-8") + agents_note, encoding="utf-8", newline="\n")

subprocess.check_call(["git", "diff", "--check"], cwd=repo)
changed = sorted(
    line[3:]
    for line in subprocess.check_output(
        ["git", "status", "--porcelain"], cwd=repo, text=True
    ).splitlines()
)
expected = sorted(
    [
        ".github/workflows/pdf-tunner-webview2-fixed-stage.yml",
        "AGENTS.md",
        "README.md",
    ]
)
if changed != expected:
    raise SystemExit(f"Unexpected staging diff: {changed}")

subprocess.check_call(["git", "config", "user.name", "WillsitoGG"], cwd=repo)
subprocess.check_call(
    ["git", "config", "user.email", "179575519+WillsitoGG@users.noreply.github.com"],
    cwd=repo,
)
subprocess.check_call(["git", "add", "--", *expected], cwd=repo)
subprocess.check_call(
    ["git", "commit", "-m", "ci(portable): persist WebView2 live failure evidence"],
    cwd=repo,
)
subprocess.check_call(
    ["git", "push", "origin", "HEAD:pdf-tunner/webview2-fixed-v151-final-stage"],
    cwd=repo,
)
print(run("git", "rev-parse", "HEAD"))
