param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
  [Parameter(Mandatory = $true)][string]$LibreOfficeMsiSha256,
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
  $p = [System.Diagnostics.Process]::new()
  $p.StartInfo = $psi
  if (-not $p.Start()) { throw "Failed to start $FilePath" }
  $stdoutTask = $p.StandardOutput.ReadToEndAsync()
  $stderrTask = $p.StandardError.ReadToEndAsync()
  $p.WaitForExit()
  return [pscustomobject]@{
    ExitCode = $p.ExitCode
    Output = (($stdoutTask.GetAwaiter().GetResult() + [Environment]::NewLine + $stderrTask.GetAwaiter().GetResult()).Trim())
  }
}

function New-MinimalDocx {
  param([Parameter(Mandatory = $true)][string]$Path, [string]$Text)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-lo-shim-docx-" + [guid]::NewGuid().ToString('N'))
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

function Wait-File {
  param([Parameter(Mandatory = $true)][string]$Path, [int]$TimeoutSeconds = 15)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return $true }
    Start-Sleep -Milliseconds 200
  }
  return $false
}

function Assert-Pdf {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected PDF missing: $Path" }
  if ((Get-Item -LiteralPath $Path).Length -le 16) { throw "PDF too small: $Path" }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ([System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(5, $bytes.Length)) -ne '%PDF-') {
    throw "Output is not PDF: $Path"
  }
}

function Assert-Docx {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected DOCX missing: $Path" }
  if ((Get-Item -LiteralPath $Path).Length -le 32) { throw "DOCX too small: $Path" }
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) { throw "Output is not ZIP/DOCX: $Path" }
}

function Get-LibreOfficeProcessesUnderRoot {
  param([Parameter(Mandatory = $true)][string]$Root)
  $programRoot = [System.IO.Path]::GetFullPath((Join-Path $Root 'tools\libreoffice\program')).TrimEnd('\') + '\'
  return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $exe = [string]$_.ExecutablePath
    $cmd = [string]$_.CommandLine
    return (($exe -and $exe.StartsWith($programRoot, [System.StringComparison]::OrdinalIgnoreCase)) -or
            ($cmd -and $cmd.IndexOf($programRoot, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
  })
}

function Assert-NoLibreOfficeProcesses {
  param([Parameter(Mandatory = $true)][string]$Root, [string]$Label)
  $deadline = [DateTime]::UtcNow.AddSeconds(10)
  do {
    $remaining = @(Get-LibreOfficeProcessesUnderRoot -Root $Root)
    if ($remaining.Count -eq 0) { return }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "LibreOffice processes remained after ${Label}: $($remaining.ProcessId -join ',')"
}

function Invoke-DirectSoffice {
  param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
  $soffice = Join-Path $Root 'tools\libreoffice\program\soffice.com'
  $work = Join-Path $Root ("data\tmp\" + $Label)
  $profile = Join-Path $Root ("data\tmp\libreoffice_profile_" + $Label)
  $nativeTemp = Join-Path $Root 'data\tmp\libreoffice-native'
  $out = Join-Path $work 'out'
  New-Item -ItemType Directory -Force -Path $work, $profile, $nativeTemp, $out | Out-Null
  $input = Join-Path $work 'input.docx'
  $pdf = Join-Path $out 'input.pdf'
  New-MinimalDocx -Path $input -Text "PDF_Tunner direct soffice fallback test: $Label"
  $result = Invoke-CapturedProcess -FilePath $soffice -Arguments @(
    ('-env:UserInstallation=' + (Get-FileUri -Path $profile)),
    '--headless','--nologo','--convert-to','pdf','--outdir',$out,$input
  ) -EnvironmentOverrides @{ TEMP=$nativeTemp; TMP=$nativeTemp }
  if ($result.ExitCode -ne 0) { throw "Direct soffice failed ($Label): $($result.Output)" }
  if (-not (Wait-File -Path $pdf)) { throw "Direct soffice returned success but PDF did not appear ($Label): $($result.Output)" }
  Assert-Pdf -Path $pdf
  Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
  Assert-NoLibreOfficeProcesses -Root $Root -Label $Label
  return $pdf
}

function Invoke-ShimRoundTrip {
  param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
  $shim = Join-Path $Root 'tools\bin\unoconvert.exe'
  $work = Join-Path $Root ("data\tmp\shim-" + $Label)
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  $input = Join-Path $work 'source.docx'
  $pdf = Join-Path $work 'requested-name.pdf'
  $docxBack = Join-Path $work 'roundtrip.docx'
  New-MinimalDocx -Path $input -Text "PDF_Tunner unoconvert shim test: $Label"

  $version = Invoke-CapturedProcess -FilePath $shim -Arguments @('--version')
  if ($version.ExitCode -ne 0 -or $version.Output -notmatch [regex]::Escape($LibreOfficeVersion)) {
    throw "unoconvert shim version probe failed: $($version.Output)"
  }

  $toPdf = Invoke-CapturedProcess -FilePath $shim -Arguments @(
    '--host','127.0.0.1','--port','2003','--host-location','local','--protocol','http',
    '--convert-to','pdf',$input,$pdf
  )
  if ($toPdf.ExitCode -ne 0) { throw "unoconvert Office->PDF failed ($Label): $($toPdf.Output)" }
  if (-not (Wait-File -Path $pdf)) { throw "unoconvert Office->PDF returned success but output did not appear ($Label)" }
  Assert-Pdf -Path $pdf

  $toDocx = Invoke-CapturedProcess -FilePath $shim -Arguments @(
    '--host','127.0.0.1','--port','2003','--convert-to','docx','--input-filter=writer_pdf_import',$pdf,$docxBack
  )
  if ($toDocx.ExitCode -ne 0) { throw "unoconvert PDF->DOCX failed ($Label): $($toDocx.Output)" }
  if (-not (Wait-File -Path $docxBack)) { throw "unoconvert PDF->DOCX returned success but output did not appear ($Label)" }
  Assert-Docx -Path $docxBack

  $profileRoot = Join-Path $Root 'p'
  if (Test-Path -LiteralPath $profileRoot -PathType Container) {
    $leftovers = @(Get-ChildItem -LiteralPath $profileRoot -Force -ErrorAction SilentlyContinue)
    if ($leftovers.Count -ne 0) { throw "Shim left profile state behind: $($leftovers.FullName -join ', ')" }
  }
  Assert-NoLibreOfficeProcesses -Root $Root -Label ("shim-" + $Label)
  return [pscustomobject]@{ Version=$version.Output; Pdf=$pdf; Docx=$docxBack }
}

$sourceRoot = [System.IO.Path]::GetFullPath($CandidateRoot)
$provenance = Join-Path $sourceRoot 'LIBREOFFICE_WINDOWS_PROVENANCE.txt'
if (-not (Test-Path -LiteralPath $provenance -PathType Leaf)) { throw "Missing provenance: $provenance" }
$prov = Get-Content -LiteralPath $provenance -Raw
foreach ($required in @(
  "LIBREOFFICE_VERSION=$LibreOfficeVersion",
  "LIBREOFFICE_MSI_SHA256=$($LibreOfficeMsiSha256.ToLowerInvariant())",
  'WINDOWS_UNOCONVERT_STRATEGY=package-local native CLI compatibility shim backed by bundled soffice'
)) {
  if ($prov.ToLowerInvariant() -notmatch [regex]::Escape($required.ToLowerInvariant())) { throw "Provenance mismatch: $required" }
}

$runnerTemp = [System.IO.Path]::GetFullPath($env:RUNNER_TEMP)
$rootA = Join-Path $runnerTemp 'PT Space\PDF Tunner'
$rootB = Join-Path $runnerTemp 'PT Moved\PDF Tunner'
Remove-Item -LiteralPath (Split-Path -Parent $rootA) -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Split-Path -Parent $rootB) -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rootA) | Out-Null
Copy-Item -LiteralPath $sourceRoot -Destination $rootA -Recurse -Force

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("LIBREOFFICE_VERSION=$LibreOfficeVersion")
$lines.Add("ROOT_A=$rootA")
$lines.Add("ROOT_A_LEN=$($rootA.Length)")
$lines.Add("ROOT_B=$rootB")
$lines.Add("ROOT_B_LEN=$($rootB.Length)")
$lines.Add('EXTREME_LONG_PATHS_NOT_ACCEPTED_BY_THIS_GATE=true')

$sofficeA = Join-Path $rootA 'tools\libreoffice\program\soffice.com'
$shimA = Join-Path $rootA 'tools\bin\unoconvert.exe'
if (-not (Test-Path -LiteralPath $sofficeA -PathType Leaf)) { throw "Missing packaged soffice.com: $sofficeA" }
if (-not (Test-Path -LiteralPath $shimA -PathType Leaf)) { throw "Missing packaged unoconvert.exe: $shimA" }

$directA = Invoke-DirectSoffice -Root $rootA -Label 'direct-a'
$lines.Add('DIRECT_SOFFICE_ROOT_A=PASS')
$shimResultA = Invoke-ShimRoundTrip -Root $rootA -Label 'a'
$lines.Add('UNOCONVERT_SHIM_OFFICE_TO_PDF_ROOT_A=PASS')
$lines.Add('UNOCONVERT_SHIM_PDF_TO_DOCX_ROOT_A=PASS')
$lines.Add("UNOCONVERT_VERSION_ROOT_A=$(($shimResultA.Version -replace "`r|`n", ' ').Trim())")

$oldPath = $env:PATH
try {
  $env:PATH = ((Join-Path $rootA 'tools\bin') + ';' + (Join-Path $rootA 'tools\libreoffice\program') + ';' + $oldPath)
  $whereUno = Invoke-CapturedProcess -FilePath (Join-Path $env:SystemRoot 'System32\where.exe') -Arguments @('unoconvert')
  $whereSoffice = Invoke-CapturedProcess -FilePath (Join-Path $env:SystemRoot 'System32\where.exe') -Arguments @('soffice')
  if ($whereUno.ExitCode -ne 0 -or $whereUno.Output -notmatch [regex]::Escape($shimA)) { throw "where unoconvert did not resolve package shim: $($whereUno.Output)" }
  if ($whereSoffice.ExitCode -ne 0 -or $whereSoffice.Output -notmatch [regex]::Escape((Join-Path $rootA 'tools\libreoffice\program'))) { throw "where soffice did not resolve package LibreOffice: $($whereSoffice.Output)" }
  $lines.Add('EXTERNAL_DEP_PROBE_PATH_ROOT_A=PASS')
} finally {
  $env:PATH = $oldPath
}

Assert-NoLibreOfficeProcesses -Root $rootA -Label 'before relocation'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rootB) | Out-Null
Move-Item -LiteralPath $rootA -Destination $rootB
if (Test-Path -LiteralPath $rootA) { throw "Old root remains after move: $rootA" }
if (-not (Test-Path -LiteralPath $rootB -PathType Container)) { throw "Moved root missing: $rootB" }
$lines.Add('RELOCATION_AFTER_USE=PASS')

$directB = Invoke-DirectSoffice -Root $rootB -Label 'direct-b'
$lines.Add('DIRECT_SOFFICE_ROOT_B=PASS')
$shimResultB = Invoke-ShimRoundTrip -Root $rootB -Label 'b'
$lines.Add('UNOCONVERT_SHIM_OFFICE_TO_PDF_ROOT_B=PASS')
$lines.Add('UNOCONVERT_SHIM_PDF_TO_DOCX_ROOT_B=PASS')

$oldPath = $env:PATH
try {
  $shimB = Join-Path $rootB 'tools\bin\unoconvert.exe'
  $env:PATH = ((Join-Path $rootB 'tools\bin') + ';' + (Join-Path $rootB 'tools\libreoffice\program') + ';' + $oldPath)
  $whereUno = Invoke-CapturedProcess -FilePath (Join-Path $env:SystemRoot 'System32\where.exe') -Arguments @('unoconvert')
  $probeUno = Invoke-CapturedProcess -FilePath 'unoconvert.exe' -Arguments @('--version')
  if ($whereUno.ExitCode -ne 0 -or $whereUno.Output -notmatch [regex]::Escape($shimB)) { throw "Moved where unoconvert failed: $($whereUno.Output)" }
  if ($probeUno.ExitCode -ne 0 -or $probeUno.Output -notmatch [regex]::Escape($LibreOfficeVersion)) { throw "Moved unoconvert --version failed: $($probeUno.Output)" }
  $lines.Add('EXTERNAL_DEP_PROBE_PATH_ROOT_B=PASS')
} finally {
  $env:PATH = $oldPath
}

Assert-NoLibreOfficeProcesses -Root $rootB -Label 'final validation'
$lines.Add('NO_PACKAGE_LIBREOFFICE_RESIDUAL_PROCESSES=PASS')
$lines.Add('WINDOWS_LIBREOFFICE_SHIM_CANDIDATE=PASS')
$lines | Set-Content -LiteralPath $EvidencePath -Encoding utf8
Write-Host 'PASS: realistic-path LibreOffice + native unoconvert compatibility shim candidate.'
Write-Host "Evidence: $EvidencePath"
