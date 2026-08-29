param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
  [Parameter(Mandatory = $true)][string]$LibreOfficeMsiSha256,
  [Parameter(Mandatory = $true)][string]$UnoServerVersion,
  [Parameter(Mandatory = $true)][string]$UnoServerWheelSha256,
  [Parameter(Mandatory = $true)][string]$EvidencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-CapturedProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @(),
    [hashtable]$EnvironmentOverrides = @{}
  )
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FilePath
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  foreach ($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }
  foreach ($key in $EnvironmentOverrides.Keys) { $psi.Environment[$key] = [string]$EnvironmentOverrides[$key] }
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  if (-not $process.Start()) { throw "Failed to start $FilePath" }
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  return [pscustomobject]@{
    ExitCode = $process.ExitCode
    Output = (($stdoutTask.GetAwaiter().GetResult() + [Environment]::NewLine + $stderrTask.GetAwaiter().GetResult()).Trim())
  }
}

function New-MinimalDocx {
  param([Parameter(Mandatory = $true)][string]$Path, [string]$Text)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-lo-subst-docx-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path (Join-Path $scratch '_rels'), (Join-Path $scratch 'word') | Out-Null
  @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@.Trim() | Set-Content -LiteralPath (Join-Path $scratch '[Content_Types].xml') -Encoding utf8
  @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@.Trim() | Set-Content -LiteralPath (Join-Path $scratch '_rels\.rels') -Encoding utf8
  $escaped = [System.Security.SecurityElement]::Escape($Text)
  @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>$escaped</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
"@.Trim() | Set-Content -LiteralPath (Join-Path $scratch 'word\document.xml') -Encoding utf8
  Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  [System.IO.Compression.ZipFile]::CreateFromDirectory($scratch, $Path)
  Remove-Item -LiteralPath $scratch -Recurse -Force
}

function Get-FileUri {
  param([Parameter(Mandatory = $true)][string]$Path)
  return ([System.Uri][System.IO.Path]::GetFullPath($Path)).AbsoluteUri
}

function Test-Pdf {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  if ((Get-Item -LiteralPath $Path).Length -le 16) { return $false }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  return ([System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(5, $bytes.Length)) -eq '%PDF-')
}

function Wait-File {
  param([string]$Path, [int]$TimeoutSeconds = 35)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return $true }
    Start-Sleep -Milliseconds 250
  }
  return $false
}

function Wait-TcpPort {
  param([string]$HostName, [int]$Port, [int]$TimeoutSeconds = 35)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
      $async = $client.ConnectAsync($HostName, $Port)
      if ($async.Wait(750) -and $client.Connected) { return $true }
    } catch {} finally { $client.Dispose() }
    Start-Sleep -Milliseconds 300
  }
  return $false
}

function Get-LibreOfficeProcessesUnderRoot {
  param([Parameter(Mandatory = $true)][string]$Root)
  $programRoot = [System.IO.Path]::GetFullPath((Join-Path $Root 'tools\libreoffice\program')).TrimEnd('\') + '\'
  return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    if ($_.Name -notmatch '(?i)^soffice(?:\.bin|\.exe|\.com)?$') { return $false }
    $exe = [string]$_.ExecutablePath
    $cmd = [string]$_.CommandLine
    return (($exe -and $exe.StartsWith($programRoot, [System.StringComparison]::OrdinalIgnoreCase)) -or
            ($cmd -and $cmd.IndexOf($programRoot, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
  })
}

function Stop-ProcessTree {
  param([int]$ProcessId)
  $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
  foreach ($child in $children) { Stop-ProcessTree -ProcessId $child.ProcessId }
  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Stop-LibreOfficeProcessesUnderRoot {
  param([Parameter(Mandatory = $true)][string]$Root, [int]$TimeoutSeconds = 15)
  $before = @(Get-LibreOfficeProcessesUnderRoot -Root $Root)
  foreach ($process in $before) { Stop-ProcessTree -ProcessId $process.ProcessId }
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $remaining = @(Get-LibreOfficeProcessesUnderRoot -Root $Root)
    if ($remaining.Count -eq 0) { break }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  return [pscustomobject]@{ Before=$before; Remaining=$remaining }
}

$substExe = Join-Path $env:SystemRoot 'System32\subst.exe'
if (-not (Test-Path -LiteralPath $substExe -PathType Leaf)) { throw "subst.exe missing: $substExe" }

function New-SubstDrive {
  param([Parameter(Mandatory = $true)][string]$TargetPath)
  New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
  $usedLetters = @([System.IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0,1).ToUpperInvariant() })
  foreach ($letter in 'ZYXWVUTSRQPONMLKJIHGFED'.ToCharArray()) {
    $letterText = [string]$letter
    $drive = "${letterText}:"
    $driveRoot = "${letterText}:\"
    if ($usedLetters -contains $letterText) { continue }
    if (Get-PSDrive -Name $letterText -PSProvider FileSystem -ErrorAction SilentlyContinue) { continue }
    $result = Invoke-CapturedProcess -FilePath $substExe -Arguments @($drive, [System.IO.Path]::GetFullPath($TargetPath))
    if ($result.ExitCode -eq 0 -and [System.IO.Directory]::Exists($driveRoot)) {
      return $drive
    }
  }
  throw "Unable to allocate a free SUBST drive for $TargetPath"
}

function Remove-SubstDrive {
  param([string]$Drive)
  if (-not $Drive) { return }
  $driveRoot = $Drive + '\'
  $result = Invoke-CapturedProcess -FilePath $substExe -Arguments @($Drive, '/d')
  if ($result.ExitCode -ne 0) { throw "Failed to remove SUBST drive $Drive: $($result.Output)" }
  if ([System.IO.Directory]::Exists($driveRoot)) { throw "SUBST drive still exists after removal: $Drive" }
}

function Invoke-DirectConversion {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$ProfileAliasPath
  )
  $sofficeCom = Join-Path $Root 'tools\libreoffice\program\soffice.com'
  $sofficeExe = Join-Path $Root 'tools\libreoffice\program\soffice.exe'
  $soffice = if (Test-Path -LiteralPath $sofficeCom -PathType Leaf) { $sofficeCom } else { $sofficeExe }
  if (-not (Test-Path -LiteralPath $soffice -PathType Leaf)) { throw "LibreOffice launcher missing: $soffice" }
  New-Item -ItemType Directory -Force -Path $ProfileAliasPath | Out-Null
  $work = Join-Path $Root ("data\" + $Label)
  $temp = Join-Path $work 't'
  $out = Join-Path $work 'o'
  New-Item -ItemType Directory -Force -Path $temp, $out | Out-Null
  $docx = Join-Path $work 'i.docx'
  $pdf = Join-Path $out 'i.pdf'
  New-MinimalDocx -Path $docx -Text "PDF_Tunner SUBST profile validation: $Label"
  $profileUri = Get-FileUri -Path $ProfileAliasPath
  $result = Invoke-CapturedProcess -FilePath $soffice -Arguments @(
    ('-env:UserInstallation=' + $profileUri), '--headless', '--nologo', '--convert-to', 'pdf', '--outdir', $out, $docx
  ) -EnvironmentOverrides @{ TEMP=$temp; TMP=$temp }
  if ($result.ExitCode -ne 0 -or -not (Wait-File -Path $pdf -TimeoutSeconds 35) -or -not (Test-Pdf -Path $pdf)) {
    throw "SUBST-profile LibreOffice conversion failed ($Label). Exit=$($result.ExitCode) Profile=$profileUri Output=$($result.Output)"
  }
  return [pscustomobject]@{ Pdf=$pdf; ProfileUri=$profileUri; Output=(($result.Output -replace "`r|`n", ' ').Trim()) }
}

$sourceRoot = [System.IO.Path]::GetFullPath($CandidateRoot)
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "Candidate root missing: $sourceRoot" }
$provenance = Join-Path $sourceRoot 'LIBREOFFICE_UNO_PROVENANCE.txt'
if (-not (Test-Path -LiteralPath $provenance -PathType Leaf)) { throw "Candidate provenance missing: $provenance" }
$prov = Get-Content -LiteralPath $provenance -Raw
foreach ($required in @(
  "LIBREOFFICE_VERSION=$LibreOfficeVersion",
  "LIBREOFFICE_MSI_SHA256=$($LibreOfficeMsiSha256.ToLowerInvariant())",
  "UNOSERVER_VERSION=$UnoServerVersion",
  "UNOSERVER_WHEEL_SHA256=$($UnoServerWheelSha256.ToLowerInvariant())"
)) {
  if ($prov.ToLowerInvariant() -notmatch [regex]::Escape($required.ToLowerInvariant())) { throw "Provenance mismatch: $required" }
}

$evidenceParent = Split-Path -Parent ([System.IO.Path]::GetFullPath($EvidencePath))
New-Item -ItemType Directory -Force -Path $evidenceParent | Out-Null
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("LIBREOFFICE_VERSION=$LibreOfficeVersion")
$lines.Add("UNOSERVER_VERSION=$UnoServerVersion")
$lines.Add("SOURCE_ROOT=$sourceRoot")

$parent = Split-Path -Parent $sourceRoot
$testParent = Join-Path $parent 'subst-profile-candidate'
Remove-Item -LiteralPath $testParent -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testParent | Out-Null
$rootA = Join-Path $testParent 'PDF Tunner LibreOffice SUBST Candidate - First Long Location With Spaces'
$rootB = Join-Path $testParent 'PDF Tunner LibreOffice SUBST Candidate - Second Long Location After Move With Spaces'
Copy-Item -LiteralPath $sourceRoot -Destination $rootA -Recurse -Force
$lines.Add("ROOT_A=$rootA")
$lines.Add("ROOT_A_LEN=$($rootA.Length)")
$lines.Add("ROOT_B=$rootB")
$lines.Add("ROOT_B_LEN=$($rootB.Length)")

$drive = $null
$server = $null
$serverStdoutTask = $null
$serverStderrTask = $null
try {
  $profileBaseA = Join-Path $rootA 'data\lo-profile'
  $drive = New-SubstDrive -TargetPath $profileBaseA
  $aliasProfile = $drive + '\direct'
  $aliasProbe = $drive + '\alias-proof.txt'
  'PDF_TUNNER_SUBST_ALIAS_OK' | Set-Content -LiteralPath $aliasProbe -Encoding ascii
  $physicalProbe = Join-Path $profileBaseA 'alias-proof.txt'
  if (-not (Test-Path -LiteralPath $physicalProbe -PathType Leaf)) { throw "SUBST alias did not resolve to package-local physical target: $physicalProbe" }
  $lines.Add("SUBST_DRIVE_FIRST=$drive")
  $lines.Add("SUBST_TARGET_FIRST=$profileBaseA")
  $lines.Add("SUBST_ALIAS_PROOF_OK=true")

  $sofficeComA = Join-Path $rootA 'tools\libreoffice\program\soffice.com'
  $versionA = Invoke-CapturedProcess -FilePath $sofficeComA -Arguments @('--version')
  if ($versionA.ExitCode -ne 0 -or $versionA.Output -notmatch [regex]::Escape($LibreOfficeVersion)) { throw "LibreOffice version failed in root A: $($versionA.Output)" }
  $first = Invoke-DirectConversion -Root $rootA -Label 'd1' -ProfileAliasPath $aliasProfile
  $lines.Add("DIRECT_COLD_SUBST_OK=true")
  $lines.Add("DIRECT_COLD_PROFILE_URI=$($first.ProfileUri)")
  $lines.Add("DIRECT_COLD_OUTPUT=$($first.Output)")
  $cleanupA = Stop-LibreOfficeProcessesUnderRoot -Root $rootA
  if ($cleanupA.Remaining.Count -ne 0) { throw "LibreOffice residual processes remain before move: $($cleanupA.Remaining.ProcessId -join ',')" }
  $lines.Add("DIRECT_COLD_RESIDUAL_BEFORE_MOVE=$($cleanupA.Before.Count)")

  $physicalDirectProfileA = Join-Path $profileBaseA 'direct'
  $profileFilesA = @(Get-ChildItem -LiteralPath $physicalDirectProfileA -Recurse -File -Force -ErrorAction SilentlyContinue)
  if ($profileFilesA.Count -eq 0) { throw "LibreOffice did not materialize profile data through SUBST under $physicalDirectProfileA" }
  $markerA = Join-Path $physicalDirectProfileA 'PDF_TUNNER_PROFILE_MOVE_MARKER.txt'
  'persist-across-move' | Set-Content -LiteralPath $markerA -Encoding ascii
  $lines.Add("PROFILE_FILE_COUNT_BEFORE_MOVE=$($profileFilesA.Count)")

  Remove-SubstDrive -Drive $drive
  $lines.Add("SUBST_REMOVED_BEFORE_MOVE=true")
  $drive = $null

  Remove-Item -LiteralPath $rootB -Recurse -Force -ErrorAction SilentlyContinue
  Move-Item -LiteralPath $rootA -Destination $rootB
  if (Test-Path -LiteralPath $rootA) { throw "Root A still exists after same-volume move: $rootA" }
  if (-not (Test-Path -LiteralPath $rootB -PathType Container)) { throw "Root B missing after same-volume move: $rootB" }
  $lines.Add("SAME_VOLUME_MOVE_AFTER_USE_OK=true")

  $profileBaseB = Join-Path $rootB 'data\lo-profile'
  $physicalDirectProfileB = Join-Path $profileBaseB 'direct'
  if (-not (Test-Path -LiteralPath (Join-Path $physicalDirectProfileB 'PDF_TUNNER_PROFILE_MOVE_MARKER.txt') -PathType Leaf)) {
    throw 'Profile marker did not move with the portable tree.'
  }
  $drive = New-SubstDrive -TargetPath $profileBaseB
  $aliasProfile = $drive + '\direct'
  $lines.Add("SUBST_DRIVE_SECOND=$drive")
  $lines.Add("SUBST_TARGET_SECOND=$profileBaseB")
  $second = Invoke-DirectConversion -Root $rootB -Label 'd2' -ProfileAliasPath $aliasProfile
  $lines.Add("DIRECT_AFTER_MOVE_SUBST_OK=true")
  $lines.Add("DIRECT_AFTER_MOVE_PROFILE_URI=$($second.ProfileUri)")
  $lines.Add("DIRECT_AFTER_MOVE_OUTPUT=$($second.Output)")
  $cleanupB = Stop-LibreOfficeProcessesUnderRoot -Root $rootB
  if ($cleanupB.Remaining.Count -ne 0) { throw "LibreOffice residual processes remain after moved conversion: $($cleanupB.Remaining.ProcessId -join ',')" }
  $lines.Add("DIRECT_AFTER_MOVE_RESIDUAL=$($cleanupB.Before.Count)")

  $loPython = Join-Path $rootB 'tools\libreoffice\program\python.exe'
  $unoRoot = Join-Path $rootB 'tools\unoserver'
  if (-not (Test-Path -LiteralPath $loPython -PathType Leaf)) { throw "LibreOffice Python missing: $loPython" }
  $unoTemp = Join-Path $rootB 'data\tmp\uno'
  $unoWork = Join-Path $rootB 'data\uno-test'
  New-Item -ItemType Directory -Force -Path $unoTemp, $unoWork | Out-Null
  $pythonEnv = @{ PYTHONPATH=$unoRoot; TEMP=$unoTemp; TMP=$unoTemp }
  $import = Invoke-CapturedProcess -FilePath $loPython -Arguments @('-c', "import uno, importlib.metadata as m; print('PYUNO_OK'); print(m.version('unoserver'))") -EnvironmentOverrides $pythonEnv
  if ($import.ExitCode -ne 0 -or $import.Output -notmatch 'PYUNO_OK' -or $import.Output -notmatch [regex]::Escape($UnoServerVersion)) {
    throw "PyUNO/unoserver import failed: $($import.Output)"
  }
  $lines.Add("PYUNO_IMPORT_OK=true")
  $lines.Add("PYUNO_IMPORT_OUTPUT=$(($import.Output -replace "`r|`n", ' ').Trim())")

  $unoAliasProfile = $drive + '\uno'
  New-Item -ItemType Directory -Force -Path $unoAliasProfile | Out-Null
  $unoProfilePhysical = Join-Path $profileBaseB 'uno'
  $sofficeExeB = Join-Path $rootB 'tools\libreoffice\program\soffice.exe'
  $pidFile = Join-Path $rootB 'data\uno-libreoffice.pid'
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $loPython
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  foreach ($arg in @(
    '-m','unoserver.server',
    '--interface','127.0.0.1','--port','2003',
    '--uno-interface','127.0.0.1','--uno-port','2004',
    '--executable',$sofficeExeB,
    '--user-installation',$unoAliasProfile,
    '--libreoffice-pid-file',$pidFile,
    '--conversion-timeout','60',
    '--temp-dir',$unoTemp,
    '--verbose'
  )) { [void]$psi.ArgumentList.Add($arg) }
  foreach ($key in $pythonEnv.Keys) { $psi.Environment[$key] = [string]$pythonEnv[$key] }
  $server = [System.Diagnostics.Process]::new()
  $server.StartInfo = $psi
  if (-not $server.Start()) { throw 'Failed to start unoserver.' }
  $serverStdoutTask = $server.StandardOutput.ReadToEndAsync()
  $serverStderrTask = $server.StandardError.ReadToEndAsync()
  if (-not (Wait-TcpPort -HostName '127.0.0.1' -Port 2003 -TimeoutSeconds 35)) {
    throw 'unoserver XML-RPC port 2003 did not become ready.'
  }
  $lines.Add("UNOSERVER_XMLRPC_READY=true")
  $lines.Add("UNOSERVER_PROFILE_ALIAS=$unoAliasProfile")
  $lines.Add("UNOSERVER_PROFILE_PHYSICAL=$unoProfilePhysical")

  $unoDocx = Join-Path $unoWork 'input.docx'
  $unoPdf = Join-Path $unoWork 'output.pdf'
  New-MinimalDocx -Path $unoDocx -Text 'PDF_Tunner real unoserver conversion through SUBST-contained profile'
  Remove-Item -LiteralPath $unoPdf -Force -ErrorAction SilentlyContinue
  $convert = Invoke-CapturedProcess -FilePath $loPython -Arguments @(
    '-m','unoserver.converter','--host','127.0.0.1','--port','2003','--host-location','local','--convert-to','pdf',$unoDocx,$unoPdf
  ) -EnvironmentOverrides $pythonEnv
  if ($convert.ExitCode -ne 0 -or -not (Wait-File -Path $unoPdf -TimeoutSeconds 35) -or -not (Test-Pdf -Path $unoPdf)) {
    throw "unoserver conversion failed. Exit=$($convert.ExitCode) Output=$($convert.Output)"
  }
  $lines.Add("UNOCONVERT_REAL_OK=true")
  $lines.Add("UNOCONVERT_OUTPUT=$(($convert.Output -replace "`r|`n", ' ').Trim())")

  if ($server.HasExited) {
    $earlyOutput = (($serverStdoutTask.GetAwaiter().GetResult() + [Environment]::NewLine + $serverStderrTask.GetAwaiter().GetResult()) -replace "`r|`n", ' ').Trim()
    throw "unoserver exited unexpectedly before explicit shutdown. Exit=$($server.ExitCode) Output=$earlyOutput"
  }
  $server.Kill($true)
  if (-not $server.WaitForExit(10000)) { throw 'unoserver process tree did not exit after explicit shutdown.' }
  $serverOutput = (($serverStdoutTask.GetAwaiter().GetResult() + [Environment]::NewLine + $serverStderrTask.GetAwaiter().GetResult()) -replace "`r|`n", ' ').Trim()
  $lines.Add("UNOSERVER_EXPLICIT_SHUTDOWN_OK=true")
  $lines.Add("UNOSERVER_OUTPUT=$serverOutput")
  $server.Dispose()
  $server = $null
  $serverStdoutTask = $null
  $serverStderrTask = $null

  $cleanupUno = Stop-LibreOfficeProcessesUnderRoot -Root $rootB
  if ($cleanupUno.Remaining.Count -ne 0) { throw "LibreOffice residual processes remain after UNO: $($cleanupUno.Remaining.ProcessId -join ',')" }
  $lines.Add("UNO_RESIDUAL_AFTER_SERVER=$($cleanupUno.Before.Count)")
  $unoProfileFiles = @(Get-ChildItem -LiteralPath $unoProfilePhysical -Recurse -File -Force -ErrorAction SilentlyContinue)
  if ($unoProfileFiles.Count -eq 0) { throw "UNO profile was not materialized physically inside package: $unoProfilePhysical" }
  $lines.Add("UNO_PROFILE_FILE_COUNT=$($unoProfileFiles.Count)")

  Remove-SubstDrive -Drive $drive
  $lines.Add("SUBST_REMOVED_FINAL=true")
  $drive = $null
  $lines.Add("CANDIDATE_SUBST_PROFILE_GATE=PASS")
} catch {
  $lines.Add("CANDIDATE_SUBST_PROFILE_GATE=FAIL")
  $lines.Add("FAILURE=$(($_.Exception.Message -replace "`r|`n", ' ').Trim())")
  throw
} finally {
  if ($server -and -not $server.HasExited) {
    try { $server.Kill($true) } catch {}
    try { $server.WaitForExit(5000) | Out-Null } catch {}
  }
  if ($server) { try { $server.Dispose() } catch {} }
  if ($drive) {
    try { Remove-SubstDrive -Drive $drive } catch { $lines.Add("SUBST_FINAL_CLEANUP_ERROR=$(($_.Exception.Message -replace "`r|`n", ' ').Trim())") }
  }
  $lines | Set-Content -LiteralPath $EvidencePath -Encoding utf8
}

Write-Host "PASS: LibreOffice SUBST profile gate including post-use move and real UNO conversion."
Write-Host "Evidence: $EvidencePath"
