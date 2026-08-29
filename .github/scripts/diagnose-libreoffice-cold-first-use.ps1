param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
  [Parameter(Mandatory = $true)][string]$EvidencePath,
  [Parameter(Mandatory = $true)][string]$WarmRootMarkerPath
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
  $scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-lo-first-use-docx-" + [guid]::NewGuid().ToString('N'))
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

function Invoke-FirstUseProbe {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][string]$CopiesParent,
    [bool]$RunVersionProbe,
    [ValidateSet('external','package')][string]$WorkMode,
    [ValidateSet('external','package')][string]$ProfileMode,
    [ValidateSet('external','package')][string]$TempMode
  )

  $root = Join-Path $CopiesParent ("PDF Tunner LO Cold First Use - $Name - With Spaces")
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item -LiteralPath $SourceRoot -Destination $root -Recurse -Force

  $sofficeCom = Join-Path $root 'tools\libreoffice\program\soffice.com'
  $sofficeExe = Join-Path $root 'tools\libreoffice\program\soffice.exe'
  $soffice = if (Test-Path -LiteralPath $sofficeCom -PathType Leaf) { $sofficeCom } else { $sofficeExe }
  $versionExit = 'SKIPPED'
  $versionOutput = 'SKIPPED'
  $residualAfterVersion = 0
  if ($RunVersionProbe) {
    $version = Invoke-CapturedProcess -FilePath $soffice -Arguments @('--version')
    $versionExit = [string]$version.ExitCode
    $versionOutput = (($version.Output -replace "`r|`n", ' ').Trim())
    $residualAfterVersion = @(Get-LibreOfficeProcessesUnderRoot -Root $root).Count
  }

  $externalBase = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-lo-cold-first-use-" + $Name)
  Remove-Item -LiteralPath $externalBase -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $externalBase | Out-Null

  $work = if ($WorkMode -eq 'package') { Join-Path $root 'data\cold-first-use\work' } else { Join-Path $externalBase 'work' }
  $profile = if ($ProfileMode -eq 'package') { Join-Path $root 'data\cold-first-use\profile' } else { Join-Path $externalBase 'profile' }
  $temp = if ($TempMode -eq 'package') { Join-Path $root 'data\cold-first-use\tmp' } else { Join-Path $externalBase 'tmp' }
  $out = Join-Path $work 'out'
  New-Item -ItemType Directory -Force -Path $work, $profile, $temp, $out | Out-Null
  $docx = Join-Path $work 'input.docx'
  $pdf = Join-Path $out 'input.pdf'
  New-MinimalDocx -Path $docx -Text "PDF_Tunner cold first-use probe: $Name"

  $result = Invoke-CapturedProcess -FilePath $soffice -Arguments @(
    ("-env:UserInstallation=" + (Get-FileUri -Path $profile)), '--headless', '--nologo', '--convert-to', 'pdf', '--outdir', $out, $docx
  ) -EnvironmentOverrides @{ TEMP = $temp; TMP = $temp }
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  while ([DateTime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $pdf -PathType Leaf)) { Start-Sleep -Milliseconds 250 }
  $ok = ($result.ExitCode -eq 0 -and (Test-Pdf -Path $pdf))
  $residualAfterConversion = @(Get-LibreOfficeProcessesUnderRoot -Root $root).Count
  $detail = (($result.Output -replace "`r|`n", ' ').Trim())
  return [pscustomobject]@{
    Name = $Name
    Root = $root
    Pass = $ok
    Line = "PROBE_$Name=$(if ($ok) {'PASS'} else {'FAIL'})|VERSION_EXIT=$versionExit|VERSION_OUTPUT=$versionOutput|RESIDUAL_AFTER_VERSION=$residualAfterVersion|CONVERSION_EXIT=$($result.ExitCode)|RESIDUAL_AFTER_CONVERSION=$residualAfterConversion|WORK=$WorkMode|PROFILE=$ProfileMode|TEMP=$TempMode|DETAIL=$detail"
  }
}

$sourceRoot = [System.IO.Path]::GetFullPath($CandidateRoot)
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "Candidate root missing: $sourceRoot" }
$copiesParent = Join-Path (Split-Path -Parent $sourceRoot) 'cold-first-use-independent-copies'
Remove-Item -LiteralPath $copiesParent -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $copiesParent | Out-Null
$evidenceParent = Split-Path -Parent ([System.IO.Path]::GetFullPath($EvidencePath))
New-Item -ItemType Directory -Force -Path $evidenceParent | Out-Null

$specs = @(
  @{ Name='NO_VERSION_ALL_PACKAGE'; Version=$false; Work='package'; Profile='package'; Temp='package' },
  @{ Name='VERSION_ALL_PACKAGE'; Version=$true; Work='package'; Profile='package'; Temp='package' },
  @{ Name='VERSION_EXTERNAL_ALL'; Version=$true; Work='external'; Profile='external'; Temp='external' },
  @{ Name='VERSION_PACKAGE_PROFILE'; Version=$true; Work='external'; Profile='package'; Temp='external' },
  @{ Name='VERSION_PACKAGE_IO'; Version=$true; Work='package'; Profile='external'; Temp='external' },
  @{ Name='VERSION_PACKAGE_TEMP'; Version=$true; Work='external'; Profile='external'; Temp='package' }
)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("LIBREOFFICE_VERSION=$LibreOfficeVersion")
$lines.Add("SOURCE_ROOT=$sourceRoot")
$results = @()
foreach ($spec in $specs) {
  $r = Invoke-FirstUseProbe -Name $spec.Name -SourceRoot $sourceRoot -CopiesParent $copiesParent -RunVersionProbe $spec.Version -WorkMode $spec.Work -ProfileMode $spec.Profile -TempMode $spec.Temp
  $results += $r
  $lines.Add($r.Line)
  Write-Host $r.Line
}

# Preserve a dedicated fresh copy for advancing the real UNO gate after the same
# external first-use warm-up that made the sequential Run #5 matrix green.
$warmRoot = Join-Path $copiesParent 'PDF Tunner LO UNO Warmed Diagnostic - With Spaces'
Remove-Item -LiteralPath $warmRoot -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $sourceRoot -Destination $warmRoot -Recurse -Force
$warmSofficeCom = Join-Path $warmRoot 'tools\libreoffice\program\soffice.com'
$warmSofficeExe = Join-Path $warmRoot 'tools\libreoffice\program\soffice.exe'
$warmSoffice = if (Test-Path -LiteralPath $warmSofficeCom -PathType Leaf) { $warmSofficeCom } else { $warmSofficeExe }
$warmVersion = Invoke-CapturedProcess -FilePath $warmSoffice -Arguments @('--version')
$warmExternal = Join-Path ([System.IO.Path]::GetTempPath()) 'pdf-tunner-lo-uno-warmup'
Remove-Item -LiteralPath $warmExternal -Recurse -Force -ErrorAction SilentlyContinue
$warmWork = Join-Path $warmExternal 'work'; $warmProfile = Join-Path $warmExternal 'profile'; $warmTemp = Join-Path $warmExternal 'tmp'; $warmOut = Join-Path $warmWork 'out'
New-Item -ItemType Directory -Force -Path $warmWork, $warmProfile, $warmTemp, $warmOut | Out-Null
$warmDocx = Join-Path $warmWork 'input.docx'; $warmPdf = Join-Path $warmOut 'input.pdf'
New-MinimalDocx -Path $warmDocx -Text 'PDF_Tunner controlled external first-use warm-up before UNO diagnostic'
$warmResult = Invoke-CapturedProcess -FilePath $warmSoffice -Arguments @(
  ("-env:UserInstallation=" + (Get-FileUri -Path $warmProfile)), '--headless', '--nologo', '--convert-to', 'pdf', '--outdir', $warmOut, $warmDocx
) -EnvironmentOverrides @{ TEMP = $warmTemp; TMP = $warmTemp }
$warmDeadline = [DateTime]::UtcNow.AddSeconds(30)
while ([DateTime]::UtcNow -lt $warmDeadline -and -not (Test-Path -LiteralPath $warmPdf -PathType Leaf)) { Start-Sleep -Milliseconds 250 }
$warmOk = ($warmResult.ExitCode -eq 0 -and (Test-Pdf -Path $warmPdf))
$lines.Add("CONTROLLED_EXTERNAL_WARMUP=$(if ($warmOk) {'PASS'} else {'FAIL'})|VERSION_EXIT=$($warmVersion.ExitCode)|CONVERSION_EXIT=$($warmResult.ExitCode)|ROOT=$warmRoot")
$lines | Set-Content -LiteralPath $EvidencePath -Encoding utf8
if (-not $warmOk) { throw "Controlled external first-use warm-up failed; cannot advance UNO diagnostic. $($warmResult.Output)" }
$warmRoot | Set-Content -LiteralPath $WarmRootMarkerPath -Encoding utf8
Write-Host "Cold first-use matrix: $EvidencePath"
Write-Host "Warm diagnostic root: $warmRoot"
