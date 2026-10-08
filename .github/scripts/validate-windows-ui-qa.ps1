param(
  [Parameter(Mandatory=$true)][string]$CandidateDir,
  [Parameter(Mandatory=$true)][string]$EvidenceDir,
  [Parameter(Mandatory=$true)][string]$PdfFixture
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
New-Item -Path $EvidenceDir -ItemType Directory -Force | Out-Null
$evidence=(Resolve-Path -LiteralPath $EvidenceDir).Path
$fixture=(Resolve-Path -LiteralPath $PdfFixture).Path
$process=$null
$oldPath=$env:PATH
$oldWebviewArgs=$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
try {
  $files=@(Get-ChildItem -LiteralPath $CandidateDir -Filter '*.zip' -File)
  if($files.Count -ne 1){throw "Expected one unwrapped candidate zip, found $($files.Count)"}
  $zip=$files[0]
  $hash=(Get-FileHash -LiteralPath $zip.FullName -Algorithm SHA256).Hash
  if($hash -ne '5ABDEE66382A04BE063CD19BB7C8A40C844CB143A778E048D78D9891433EF95C'){throw "Unrecognized candidate SHA-256 $hash"}
  $os=Get-CimInstance Win32_OperatingSystem
  @("SourceRun=129","SourceArtifact=11541921231","SourceSHA256=$hash","ZIPBytes=$($zip.Length)","Windows=$($os.Caption)","OSBuild=$($os.BuildNumber)","ConsumerWindows10or11=NOT_TESTED") | Set-Content -LiteralPath (Join-Path $evidence 'environment.txt')
  $root=Join-Path $env:RUNNER_TEMP 'PDF Tunner QA Á Espacios'
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  Expand-Archive -LiteralPath $zip.FullName -DestinationPath $root -Force
  $exe=Join-Path $root 'PDF_Tunner.exe'
  if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'PDF_Tunner.exe missing from actual zip'}
  if(-not(Test-Path -LiteralPath (Join-Path $root 'PDF_TUNNER_PORTABLE') -PathType Leaf)){throw 'Portable marker missing'}
  if(-not(Test-Path -LiteralPath (Join-Path $root 'tools') -PathType Container)){throw 'Portable toolchain missing'}
  $nodePath=Join-Path $env:RUNNER_TEMP 'pdf-tunner-playwright-cdp'
  New-Item -Path $nodePath -ItemType Directory -Force | Out-Null
  Copy-Item -LiteralPath '.github/scripts/windows-ui-qa.cjs' -Destination (Join-Path $nodePath 'windows-ui-qa.cjs')
  Push-Location $nodePath
  try {
    & npm.cmd install --no-audit --no-fund --no-save --ignore-scripts --package-lock=false playwright-core@1.56.1
    if($LASTEXITCODE -ne 0){throw 'Playwright CDP package unavailable'}
  } finally {Pop-Location}
  # For the target process only, eliminate runner-provided interpreters and converters from PATH.
  $win=$env:SystemRoot
  $env:PATH="$win\System32;$win;$win\System32\Wbem"
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS='--remote-debugging-port=9222'
  $process=Start-Process -FilePath $exe -WorkingDirectory $root -PassThru
  $env:PATH=$oldPath
  Write-Host "Started real PDF_Tunner portable PID $($process.Id)"
  $ready=$false
  for($i=0;$i -lt 60;$i++){
    Start-Sleep -Seconds 2
    try {
      $info=Invoke-RestMethod -Uri 'http://127.0.0.1:9222/json/version' -TimeoutSec 2
      if($info.Browser -or $info.webSocketDebuggerUrl){$ready=$true;break}
    } catch {}
    $process.Refresh()
    if($process.HasExited){throw "Portable exited early with $($process.ExitCode)"}
  }
  if(-not $ready){throw 'Native app started but WebView2 CDP was unavailable. GUI test NOT passed'}
  & node.exe (Join-Path $nodePath 'windows-ui-qa.cjs') $evidence $fixture
  if($LASTEXITCODE -ne 0){throw "WebView2 UI smoke failed with code $LASTEXITCODE"}
  Add-Content -LiteralPath (Join-Path $evidence 'environment.txt') -Value 'WebView2UI=PASS'
  Write-Host 'WebView2 real frontend smoke: PASS'
} catch {
  ($_ | Out-String) | Set-Content -LiteralPath (Join-Path $evidence 'failure.txt')
  throw
} finally {
  $env:PATH=$oldPath
  $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=$oldWebviewArgs
  if($null -ne $process){
    try {
      $process.Refresh()
      if(-not $process.HasExited){
        [void]$process.CloseMainWindow()
        if(-not $process.WaitForExit(20000)){
          & taskkill.exe /PID $process.Id /T /F | Out-Null
        }
      }
    } catch {Write-Warning "Cleanup issue: $_"}
  }
}
