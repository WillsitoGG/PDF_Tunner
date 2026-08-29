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

function New-MinimalDocx {
  param([Parameter(Mandatory = $true)][string]$Path, [string]$Text = 'PDF_Tunner LibreOffice portable conversion')
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $work = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-docx-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path (Join-Path $work '_rels'), (Join-Path $work 'word') | Out-Null
  $contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@
  $contentTypes.Trim() | Set-Content -LiteralPath (Join-Path $work '[Content_Types].xml') -Encoding utf8
  $relationships = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@
  $relationships.Trim() | Set-Content -LiteralPath (Join-Path $work '_rels\.rels') -Encoding utf8
  $escaped = [System.Security.SecurityElement]::Escape($Text)
  $documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>$escaped</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
"@
  $documentXml.Trim() | Set-Content -LiteralPath (Join-Path $work 'word\document.xml') -Encoding utf8
  Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  [System.IO.Compression.ZipFile]::CreateFromDirectory($work, $Path)
  Remove-Item -LiteralPath $work -Recurse -Force
}

function Get-FileUri {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  return ([System.Uri]$full).AbsoluteUri
}

function Assert-Pdf {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected PDF not found: $Path" }
  if ((Get-Item -LiteralPath $Path).Length -le 16) { throw "Produced PDF is unexpectedly small: $Path" }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $header = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(5, $bytes.Length))
  if ($header -ne '%PDF-') { throw "Output is not a PDF: $Path" }
}

function Invoke-DirectLibreOfficeConversion {
  param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
  $soffice = Join-Path $Root 'tools\libreoffice\program\soffice.exe'
  if (-not (Test-Path -LiteralPath $soffice -PathType Leaf)) { throw "Missing soffice.exe: $soffice" }
  $work = Join-Path $Root ("data\validation\" + $Label)
  $profile = Join-Path $work 'profile'
  $temp = Join-Path $work 'tmp'
  $out = Join-Path $work 'out'
  New-Item -ItemType Directory -Force -Path $profile, $temp, $out | Out-Null
  $docx = Join-Path $work 'input.docx'
  New-MinimalDocx -Path $docx -Text "PDF_Tunner direct LibreOffice test: $Label"

  $oldTemp = $env:TEMP
  $oldTmp = $env:TMP
  try {
    $env:TEMP = $temp
    $env:TMP = $temp
    $profileUri = Get-FileUri -Path $profile
    $output = & $soffice ("-env:UserInstallation=" + $profileUri) '--headless' '--nologo' '--convert-to' 'pdf' '--outdir' $out $docx 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "soffice conversion failed ($Label): $($output -join [Environment]::NewLine)"
    }
  } finally {
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
  }
  $pdf = Join-Path $out 'input.pdf'
  Assert-Pdf -Path $pdf
  return $pdf
}

function Stop-ProcessTree {
  param([int]$ProcessId)
  $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
  foreach ($child in $children) { Stop-ProcessTree -ProcessId $child.ProcessId }
  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
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

$soffice = Join-Path $root 'tools\libreoffice\program\soffice.exe'
$versionOutput = & $soffice '--version' 2>&1
if ($LASTEXITCODE -ne 0 -or (($versionOutput -join "`n") -notmatch [regex]::Escape($LibreOfficeVersion))) {
  throw "LibreOffice version validation failed: $($versionOutput -join [Environment]::NewLine)"
}

$firstPdf = Invoke-DirectLibreOfficeConversion -Root $root -Label 'direct-original'
Write-Host "PASS: direct DOCX -> PDF conversion: $firstPdf"

if ($RequireRelocation) {
  $parent = Split-Path -Parent $root
  $relocated = Join-Path $parent 'PDF Tunner LibreOffice UNO Candidate - Relocated With Spaces'
  Remove-Item -LiteralPath $relocated -Recurse -Force -ErrorAction SilentlyContinue
  Move-Item -LiteralPath $root -Destination $relocated
  $root = $relocated
  $secondPdf = Invoke-DirectLibreOfficeConversion -Root $root -Label 'direct-relocated'
  Write-Host "PASS: relocated direct DOCX -> PDF conversion: $secondPdf"
}

$loPython = Join-Path $root 'tools\libreoffice\program\python.exe'
$unoRoot = Join-Path $root 'tools\unoserver'
$evidenceDir = Join-Path $root 'data\validation-evidence'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$evidencePath = Join-Path $evidenceDir 'UNO_FEASIBILITY.txt'

if (-not (Test-Path -LiteralPath $loPython -PathType Leaf)) {
  @(
    'UNO_PYTHON_PRESENT=false',
    'UNO_IMPORT_OK=false',
    'UNOSERVER_OK=false',
    'DETAIL=LibreOffice Windows package does not expose program/python.exe at the expected path.'
  ) | Set-Content -LiteralPath $evidencePath -Encoding utf8
  if ($RequireUnoServer) { throw 'LibreOffice package does not contain program\python.exe; UNO candidate cannot proceed.' }
  return
}

$oldPythonPath = $env:PYTHONPATH
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
$server = $null
try {
  $env:PYTHONPATH = $unoRoot
  $unoTemp = Join-Path $root 'data\tmp\libreoffice-uno'
  $unoProfile = Join-Path $root 'data\libreoffice\uno-profile-2003'
  New-Item -ItemType Directory -Force -Path $unoTemp, $unoProfile | Out-Null
  $env:TEMP = $unoTemp
  $env:TMP = $unoTemp

  $importOutput = & $loPython '-c' "import uno, importlib.metadata as m; print('PYUNO_OK'); print(m.version('unoserver'))" 2>&1
  $importExit = $LASTEXITCODE
  if ($importExit -ne 0 -or (($importOutput -join "`n") -notmatch 'PYUNO_OK')) {
    @(
      'UNO_PYTHON_PRESENT=true',
      'UNO_IMPORT_OK=false',
      'UNOSERVER_OK=false',
      ('DETAIL=' + (($importOutput -join ' ') -replace "`r|`n", ' '))
    ) | Set-Content -LiteralPath $evidencePath -Encoding utf8
    if ($RequireUnoServer) { throw "LibreOffice Python could not import PyUNO/unoserver: $($importOutput -join [Environment]::NewLine)" }
    return
  }
  if (($importOutput -join "`n") -notmatch [regex]::Escape($UnoServerVersion)) {
    throw "LibreOffice Python imported unoserver, but version $UnoServerVersion was not reported."
  }

  $realSoffice = Join-Path $root 'tools\libreoffice\program\soffice.exe'
  $serverArgs = @(
    '-m', 'unoserver.server',
    '--interface', '127.0.0.1',
    '--port', '2003',
    '--uno-interface', '127.0.0.1',
    '--uno-port', '2004',
    '--executable', ('"' + $realSoffice + '"'),
    '--user-installation', ('"' + $unoProfile + '"'),
    '--temp-dir', ('"' + $unoTemp + '"'),
    '--conversion-timeout', '120'
  )
  $server = Start-Process -FilePath $loPython -ArgumentList $serverArgs -PassThru -WindowStyle Hidden
  if (-not (Wait-TcpPort -HostName '127.0.0.1' -Port 2003 -TimeoutSeconds 30)) {
    throw 'unoserver did not bind 127.0.0.1:2003 within 30 seconds.'
  }

  $work = Join-Path $root 'data\validation\uno-relocated'
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  $docx = Join-Path $work 'uno-input.docx'
  $pdf = Join-Path $work 'uno-output.pdf'
  New-MinimalDocx -Path $docx -Text 'PDF_Tunner real unoserver/unoconvert conversion'
  $clientCode = 'from unoserver.client import converter_main; converter_main()'
  $clientOutput = & $loPython '-c' $clientCode '--host' '127.0.0.1' '--port' '2003' '--convert-to' 'pdf' $docx $pdf 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "unoconvert client failed: $($clientOutput -join [Environment]::NewLine)"
  }
  Assert-Pdf -Path $pdf

  @(
    'UNO_PYTHON_PRESENT=true',
    'UNO_IMPORT_OK=true',
    'UNOSERVER_OK=true',
    "UNOSERVER_VERSION=$UnoServerVersion",
    'XMLRPC_ENDPOINT=127.0.0.1:2003',
    'UNO_ENDPOINT=127.0.0.1:2004',
    'DIRECT_CONVERSION_OK=true',
    'RELOCATION_OK=true',
    'REAL_UNOCONVERT_OK=true',
    ('ROOT=' + $root)
  ) | Set-Content -LiteralPath $evidencePath -Encoding utf8
  Write-Host 'PASS: LibreOffice Python imports PyUNO; real unoserver + unoconvert conversion succeeded.'
} finally {
  if ($null -ne $server -and -not $server.HasExited) {
    Stop-ProcessTree -ProcessId $server.Id
  }
  $env:PYTHONPATH = $oldPythonPath
  $env:TEMP = $oldTemp
  $env:TMP = $oldTmp
}

Write-Host "Validation evidence: $evidencePath"
