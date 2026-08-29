param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$UnoServerVersion,
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
  $scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-lo-diag-docx-" + [guid]::NewGuid().ToString('N'))
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

function Invoke-ConversionProbe {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$LibreOfficeRoot,
    [Parameter(Mandatory = $true)][string]$WorkPath,
    [Parameter(Mandatory = $true)][string]$ProfilePath,
    [Parameter(Mandatory = $true)][string]$TempPath
  )
  try {
    $sofficeCom = Join-Path $LibreOfficeRoot 'tools\libreoffice\program\soffice.com'
    $sofficeExe = Join-Path $LibreOfficeRoot 'tools\libreoffice\program\soffice.exe'
    $soffice = if (Test-Path -LiteralPath $sofficeCom -PathType Leaf) { $sofficeCom } else { $sofficeExe }
    New-Item -ItemType Directory -Force -Path $WorkPath, $ProfilePath, $TempPath | Out-Null
    $out = Join-Path $WorkPath 'out'
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $docx = Join-Path $WorkPath 'input.docx'
    $pdf = Join-Path $out 'input.pdf'
    New-MinimalDocx -Path $docx -Text "PDF_Tunner LibreOffice relocation matrix: $Name"
    $profileUri = Get-FileUri -Path $ProfilePath
    $result = Invoke-CapturedProcess -FilePath $soffice -Arguments @(
      ("-env:UserInstallation=" + $profileUri), '--headless', '--nologo', '--convert-to', 'pdf', '--outdir', $out, $docx
    ) -EnvironmentOverrides @{ TEMP = $TempPath; TMP = $TempPath }
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while ([DateTime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $pdf -PathType Leaf)) { Start-Sleep -Milliseconds 250 }
    if ($result.ExitCode -ne 0 -or -not (Test-Pdf -Path $pdf)) {
      $detail = ($result.Output -replace "`r|`n", ' ').Trim()
      return "PROBE_$Name=FAIL|EXIT=$($result.ExitCode)|EXEC=$soffice|PROFILE_URI=$profileUri|TEMP=$TempPath|WORK=$WorkPath|DETAIL=$detail"
    }
    return "PROBE_$Name=PASS|EXIT=$($result.ExitCode)|EXEC=$soffice|PROFILE_URI=$profileUri|TEMP=$TempPath|WORK=$WorkPath|PDF=$pdf"
  } catch {
    return "PROBE_$Name=FAIL|EXCEPTION=$(($_.Exception.Message -replace "`r|`n", ' ').Trim())"
  }
}

$sourceRoot = [System.IO.Path]::GetFullPath($CandidateRoot)
$parent = Split-Path -Parent $sourceRoot
$relocatedRoot = Join-Path $parent 'PDF Tunner LibreOffice Cold Copy - Relocated With Spaces'
Remove-Item -LiteralPath $relocatedRoot -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $sourceRoot -Destination $relocatedRoot -Recurse -Force

$evidenceParent = Split-Path -Parent ([System.IO.Path]::GetFullPath($EvidencePath))
New-Item -ItemType Directory -Force -Path $evidenceParent | Out-Null
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("SOURCE_ROOT=$sourceRoot")
$lines.Add("RELOCATED_COPY_ROOT=$relocatedRoot")

$sofficeCom = Join-Path $relocatedRoot 'tools\libreoffice\program\soffice.com'
$sofficeExe = Join-Path $relocatedRoot 'tools\libreoffice\program\soffice.exe'
$soffice = if (Test-Path -LiteralPath $sofficeCom -PathType Leaf) { $sofficeCom } else { $sofficeExe }
$version = Invoke-CapturedProcess -FilePath $soffice -Arguments @('--version')
$lines.Add("RELOCATED_VERSION_EXIT=$($version.ExitCode)")
$lines.Add("RELOCATED_VERSION_OUTPUT=$(($version.Output -replace "`r|`n", ' ').Trim())")

$diagBase = Join-Path ([System.IO.Path]::GetTempPath()) 'pdf-tunner-lo-relocation-matrix'
Remove-Item -LiteralPath $diagBase -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $diagBase | Out-Null

$probeSpecs = @(
  @{ Name='EXTERNAL_ALL'; Work=(Join-Path $diagBase 'external-all\work'); Profile=(Join-Path $diagBase 'external-all\profile'); Temp=(Join-Path $diagBase 'external-all\tmp') },
  @{ Name='PACKAGE_PROFILE'; Work=(Join-Path $diagBase 'package-profile\work'); Profile=(Join-Path $relocatedRoot 'data\diagnostic-matrix\package-profile'); Temp=(Join-Path $diagBase 'package-profile\tmp') },
  @{ Name='PACKAGE_IO'; Work=(Join-Path $relocatedRoot 'data\diagnostic-matrix\package-io'); Profile=(Join-Path $diagBase 'package-io\profile'); Temp=(Join-Path $diagBase 'package-io\tmp') },
  @{ Name='PACKAGE_TEMP'; Work=(Join-Path $diagBase 'package-temp\work'); Profile=(Join-Path $diagBase 'package-temp\profile'); Temp=(Join-Path $relocatedRoot 'data\diagnostic-matrix\package-temp') },
  @{ Name='ALL_PACKAGE'; Work=(Join-Path $relocatedRoot 'data\diagnostic-matrix\all-package\work'); Profile=(Join-Path $relocatedRoot 'data\diagnostic-matrix\all-package\profile'); Temp=(Join-Path $relocatedRoot 'data\diagnostic-matrix\all-package\tmp') }
)
foreach ($probe in $probeSpecs) {
  $probeLine = Invoke-ConversionProbe -Name $probe.Name -LibreOfficeRoot $relocatedRoot -WorkPath $probe.Work -ProfilePath $probe.Profile -TempPath $probe.Temp
  $lines.Add($probeLine)
  Write-Host $probeLine
}

foreach ($rootInfo in @(@{ Prefix='SOURCE'; Root=$sourceRoot }, @{ Prefix='RELOCATED'; Root=$relocatedRoot })) {
  $python = Join-Path $rootInfo.Root 'tools\libreoffice\program\python.exe'
  $unoRoot = Join-Path $rootInfo.Root 'tools\unoserver'
  $present = Test-Path -LiteralPath $python -PathType Leaf
  $lines.Add("$($rootInfo.Prefix)_LO_PYTHON_PRESENT=$($present.ToString().ToLowerInvariant())")
  if ($present) {
    $pyTemp = Join-Path $rootInfo.Root 'data\diagnostic-matrix\python-tmp'
    New-Item -ItemType Directory -Force -Path $pyTemp | Out-Null
    $import = Invoke-CapturedProcess -FilePath $python -Arguments @('-c', "import uno, importlib.metadata as m; print('PYUNO_OK'); print(m.version('unoserver'))") -EnvironmentOverrides @{ PYTHONPATH=$unoRoot; TEMP=$pyTemp; TMP=$pyTemp }
    $lines.Add("$($rootInfo.Prefix)_PYUNO_IMPORT_EXIT=$($import.ExitCode)")
    $lines.Add("$($rootInfo.Prefix)_PYUNO_IMPORT_OUTPUT=$(($import.Output -replace "`r|`n", ' ').Trim())")
    $lines.Add("$($rootInfo.Prefix)_PYUNO_EXPECTED_UNOSERVER=$UnoServerVersion")
  }
}

$lines | Set-Content -LiteralPath $EvidencePath -Encoding utf8
Write-Host "Relocation diagnostic evidence: $EvidencePath"
