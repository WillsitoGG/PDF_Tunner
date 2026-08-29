param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
  [Parameter(Mandatory = $true)][string]$LibreOfficeMsiSha256,
  [Parameter(Mandatory = $true)][string]$UnoServerVersion,
  [Parameter(Mandatory = $true)][string]$UnoServerWheelSha256,
  [switch]$RequireRelocation,
  [switch]$RequireUnoServer
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
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  return [pscustomobject]@{
    ExitCode = $process.ExitCode
    Output = (($stdout + [Environment]::NewLine + $stderr).Trim())
  }
}

function New-MinimalDocx {
  param([Parameter(Mandatory = $true)][string]$Path, [string]$Text)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $work = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-docx-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path (Join-Path $work '_rels'), (Join-Path $work 'word') | Out-Null
  @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@.Trim() | Set-Content -LiteralPath (Join-Path $work '[Content_Types].xml') -Encoding utf8
  @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@.Trim() | Set-Content -LiteralPath (Join-Path $work '_rels\.rels') -Encoding utf8
  $escaped = [System.Security.SecurityElement]::Escape($Text)
  @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>$escaped</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
"@.Trim() | Set-Content -LiteralPath (Join-Path $work 'word\document.xml') -Encoding utf8
  Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  [System.IO.Compression.ZipFile]::CreateFromDirectory($work, $Path)
  Remove-Item -LiteralPath $work -Recurse -Force
}

function Get-FileUri {
  param([Parameter(Mandatory = $true)][string]$Path)
  return ([System.Uri][System.IO.Path]::GetFullPath($Path)).AbsoluteUri
}

function Assert-Pdf {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected PDF not found: $Path" }
  if ((Get-Item -LiteralPath $Path).Length -le 16) { throw "Produced PDF is unexpectedly small: $Path" }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $header = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(5, $bytes.Length))
  if ($header -ne '%PDF-') { throw "Output is not a PDF: $Path" }
}

function Wait-File {
  param([string]$Path, [int]$TimeoutSeconds = 30)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return $true }
    Start-Sleep -Milliseconds 250
  }
  return $false
}

function Invoke-DirectLibreOfficeConversion {
  param([string]$Root, [string]$Label)
  $sofficeCom = Join-Path $Root 'tools\libreoffice\program\soffice.com'
  $sofficeExe = Join-Path $Root 'tools\libreoffice\program\soffice.exe'
  $soffice = if (Test-Path -LiteralPath $sofficeCom -PathType Leaf) { $sofficeCom } else { $sofficeExe }
  if (-not (Test-Path -LiteralPath $soffice -PathType Leaf)) { throw "Missing LibreOffice CLI launcher: $soffice" }
  $work = Join-Path $Root ("data\validation\" + $Label)
  $profile = Join-Path $work 'profile'
  $temp = Join-Path $work 'tmp'
  $out = Join-Path $work 'out'
  New-Item -ItemType Directory -Force -Path $profile, $temp, $out | Out-Null
  $docx = Join-Path $work 'input.docx'
  New-MinimalDocx -Path $docx -Text "PDF_Tunner direct LibreOffice test: $Label"
  $profileUri = Get-FileUri -Path $profile
  $result = Invoke-CapturedProcess -FilePath $soffice -Arguments @(
    ("-env:UserInstallation=" + $profileUri), '--headless', '--nologo', '--convert-to', 'pdf', '--outdir', $out, $docx
  ) -EnvironmentOverrides @{ TEMP = $temp; TMP = $temp }
  if ($result.ExitCode -ne 0) { throw "soffice conversion failed ($Label): $($result.Output)" }
  $pdf = Join-Path $out 'input.pdf'
  if (-not (Wait-File -Path $pdf -TimeoutSeconds 30)) { throw "soffice returned success but PDF did not appear ($Label): $($result.Output)" }
  Assert-Pdf -Path $pdf
  return $pdf
}

function Stop-ProcessTree {
  param([int]$ProcessId)
  $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
  foreach ($child in $children) { Stop-ProcessTree -ProcessId $child.ProcessId }
  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
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
  return [pscustomobject]@{ Before = $before; Remaining = $remaining }
}

function Wait-TcpPort {
  param([string]$HostName, [int]$Port, [int]$TimeoutSeconds = 30)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
      $async = $client.ConnectAsync($HostName, $Port)
      if ($async.Wait(1000) -and $client.Connected) { return $true }
    } catch {} finally { $client.Dispose() }
    Start-Sleep -Milliseconds 500
  }
  return $false
}

$root = [System.IO.Path]::GetFullPath($CandidateRoot)
$provenance = Join-Path $root 'LIBREOFFICE_UNO_PROVENANCE.txt'
if (-not (Test-Path -LiteralPath $provenance -PathType Leaf)) { throw "Missing provenance: $provenance" }
$provText = Get-Content -LiteralPath $provenance -Raw
foreach ($required in @(
  "LIBREOFFICE_VERSION=$LibreOfficeVersion",
  "LIBREOFFICE_MSI_SHA256=$($LibreOfficeMsiSha256.ToLowerInvariant())",
  "UNOSERVER_VERSION=$UnoServerVersion",
  "UNOSERVER_WHEEL_SHA256=$($UnoServerWheelSha256.ToLowerInvariant())"
)) {
  if ($provText.ToLowerInvariant() -notmatch [regex]::Escape($required.ToLowerInvariant())) {
    throw "Provenance missing expected identity: $required"
  }
}

# The portable contract is validated from a cold package: relocate the complete tree
# before the first functional LibreOffice start. Run #5 proved that an already-used
# LibreOffice tree behaves differently when same-volume renamed, while a cold copy
# works with executable, profile, TEMP/TMP and I/O all under a path containing spaces.
$originalRoot = $root
if ($RequireRelocation) {
  $parent = Split-Path -Parent $root
  $relocated = Join-Path $parent 'PDF Tunner LibreOffice UNO Candidate - Relocated With Spaces'
  Remove-Item -LiteralPath $relocated -Recurse -Force -ErrorAction SilentlyContinue
  Move-Item -LiteralPath $root -Destination $relocated
  if (Test-Path -LiteralPath $originalRoot) { throw "Original candidate root still exists after cold relocation: $originalRoot" }
  $root = $relocated
}

$evidenceDir = Join-Path $root 'data\\validation-evidence'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$evidencePath = Join-Path $evidenceDir 'UNO_FEASIBILITY.txt'
@(
  'COLD_RELOCATION_BEFORE_FUNCTIONAL_START=true',
  ('ORIGINAL_ROOT=' + $originalRoot),
  ('ACTIVE_ROOT=' + $root),
  ('RELOCATION_REQUIRED=' + [bool]$RequireRelocation)
) | Set-Content -LiteralPath $evidencePath -Encoding utf8

$sofficeExe = Join-Path $root 'tools\\libreoffice\\program\\soffice.exe'
$sofficeCom = Join-Path $root 'tools\\libreoffice\\program\\soffice.com'
$versionBinary = if (Test-Path -LiteralPath $sofficeCom -PathType Leaf) { $sofficeCom } else { $sofficeExe }
$versionResult = Invoke-CapturedProcess -FilePath $versionBinary -Arguments @('--version')
if ($versionResult.ExitCode -ne 0 -or $versionResult.Output -notmatch [regex]::Escape($LibreOfficeVersion)) {
  throw "LibreOffice version validation failed after cold relocation: $($versionResult.Output)"
}
Add-Content -LiteralPath $evidencePath -Encoding utf8 -Value ('LIBREOFFFICE_VERSION_OUTPUT=' + ($versionResult.Output -replace "`r|`n", ' '))

$firstPdf = Invoke-DirectLibreOfficeConversion -Root $root -Label 'direct-first-use'
Write-Host "PASS: first real DOCX -> PDF conversion after cold relocation: $firstPdf"
Add-Content -LiteralPath $evidencePath -Encoding utf8 -Value 'DIRECT_FIRST_USE_OK=true'

$cleanup1 = Stop-LibreOfficeProcessesUnderRoot -Root $root
Add-Content -LiteralPath $evidencePath -Encoding utf8 -Value "DIRECT_FIRST_USE_RESIDUAL_COUNT=$($cleanup1.Before.Count)"
if ($cleanup1.Remaining.Count -ne 0) {
  throw "Package-local LibreOffice processes remained alive after first conversion: $($cleanup1.Remaining.ProcessId -join ', ')"
}

$secondPdf = Invoke-DirectLibreOfficeConversion -Root $root -Label 'direct-repeat-use'
Write-Host "PASS: repeated DOCX -> PDF conversion from the relocated sandbox: $secondPdf"
Add-Content -LiteralPath $evidencePath -Encoding utf8 -Value 'DIRECT_REPEAT_USE_OK=true'

$cleanup2 = Stop-LibreOfficeProcessesUnderRoot -Root $root
Add-Content -LiteralPath $evidencePath -Encoding utf8 -Value "DIRECT_REPEAT_USE_RESIDUAL_COUNT=$($cleanup2.Before.Count)"
if ($cleanup2.Remaining.Count -ne 0) {
  throw "Package-local LibreOffice processes remained alive after repeated conversion: $($cleanup2.Remaining.ProcessId -join ', ')"
}

$loPython = Join-Path $root 'tools\libreoffice\program\python.exe'
$unoRoot = Join-Path $root 'tools\unoserver'

if (-not (Test-Path -LiteralPath $loPython -PathType Leaf)) {
  @(
    'UNO_PYTHON_PRESENT=false',
    'UNO_IMPORT_OK=false',
    'UNOSERVER_OK=false',
    'DETAIL=LibreOffice Windows package does not expose program/python.exe at the expected path.'
  ) | Add-Content -LiteralPath $evidencePath -Encoding utf8
  if ($RequireUnoServer) { throw 'LibreOffice package does not contain program\python.exe; UNO candidate cannot proceed.' }
  return
}

$unoTemp = Join-Path $root 'data\tmp\libreoffice-uno'
$unoProfile = Join-Path $root 'data\libreoffice\uno-profile-2003'
New-Item -ItemType Directory -Force -Path $unoTemp, $unoProfile | Out-Null
$pythonEnv = @{ PYTHONPATH = $unoRoot; TEMP = $unoTemp; TMP = $unoTemp }

$importResult = Invoke-CapturedProcess -FilePath $loPython -Arguments @('-c', "import uno, importlib.metadata as m; print('PYUNO_OK'); print(m.version('unoserver'))") -EnvironmentOverrides $pythonEnv
if ($importResult.ExitCode -ne 0 -or $importResult.Output -notmatch 'PYUNO_OK') {
  @(
    'UNO_PYTHON_PRESENT=true',
    'UNO_IMPORT_OK=false',
    'UNOSERVER_OK=false',
    ('DETAIL=' + ($importResult.Output -replace "`r|`n", ' '))
  ) | Add-Content -LiteralPath $evidencePath -Encoding utf8
  if ($RequireUnoServer) { throw "LibreOffice Python could not import PyUNO/unoserver: $($importResult.Output)" }
  return
}
if ($importResult.Output -notmatch [regex]::Escape($UnoServerVersion)) {
  throw "LibreOffice Python imported unoserver, but version $UnoServerVersion was not reported."
}

$server = $null
try {
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $loPython
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  foreach ($arg in @(
    '-m', 'unoserver.server', '--interface', '127.0.0.1', '--port', '2003', '--uno-interface', '127.0.0.1', '--uno-port', '2004',
    '--executable', (Join-Path $root 'tools\libreoffice\program\soffice.exe'), '--user-installation', $unoProfile,
    '--temp-dir', $unoTemp, '--conversion-timeout', '120'
  )) { [void]$psi.ArgumentList.Add($arg) }
  foreach ($key in $pythonEnv.Keys) { $psi.Environment[$key] = [string]$pythonEnv[$key] }
  $server = [System.Diagnostics.Process]::new()
  $server.StartInfo = $psi
  if (-not $server.Start()) { throw 'Failed to start unoserver.' }
  if (-not (Wait-TcpPort -HostName '127.0.0.1' -Port 2003 -TimeoutSeconds 30)) {
    $serverError = $server.StandardError.ReadToEnd()
    throw "unoserver did not bind 127.0.0.1:2003 within 30 seconds. $serverError"
  }

  $work = Join-Path $root 'data\validation\uno-relocated'
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  $docx = Join-Path $work 'uno-input.docx'
  $pdf = Join-Path $work 'uno-output.pdf'
  New-MinimalDocx -Path $docx -Text 'PDF_Tunner real unoserver/unoconvert conversion'
  $clientCode = 'from unoserver.client import converter_main; converter_main()'
  $clientResult = Invoke-CapturedProcess -FilePath $loPython -Arguments @(
    '-c', $clientCode, '--host', '127.0.0.1', '--port', '2003', '--convert-to', 'pdf', $docx, $pdf
  ) -EnvironmentOverrides $pythonEnv
  if ($clientResult.ExitCode -ne 0) { throw "unoconvert client failed: $($clientResult.Output)" }
  Assert-Pdf -Path $pdf

  @(
    'UNO_PYTHON_PRESENT=true',
    'UNO_IMPORT_OK=true',
    'UNOSERVER_OK=true',
    "UNOSERVER_VERSION=$UnoServerVersion",
    'XMLRPC_ENDPOINT=127.0.0.1:2003',
    'UNO_ENDPOINT=127.0.0.1:2004',
    'DIRECT_CONVERSION_OK=true',
    'COLD_RELOCATION_OK=true',
    'REAL_UNOCONVERT_OK=true',
    ('ROOT=' + $root)
  ) | Add-Content -LiteralPath $evidencePath -Encoding utf8
  Write-Host 'PASS: LibreOffice Python imports PyUNO; real unoserver + unoconvert conversion succeeded.'
} finally {
  if ($null -ne $server -and -not $server.HasExited) { Stop-ProcessTree -ProcessId $server.Id }
}

Write-Host "Validation evidence: $evidencePath"
