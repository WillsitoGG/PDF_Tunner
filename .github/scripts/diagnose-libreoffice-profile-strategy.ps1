param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
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
  $scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-lo-profile-docx-" + [guid]::NewGuid().ToString('N'))
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

function Set-BootstrapOriginProfile {
  param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Value)
  $bootstrap = Join-Path $Root 'tools\libreoffice\program\bootstrap.ini'
  if (-not (Test-Path -LiteralPath $bootstrap -PathType Leaf)) { throw "bootstrap.ini missing: $bootstrap" }
  $text = Get-Content -LiteralPath $bootstrap -Raw
  if ($text -notmatch '(?m)^UserInstallation=.*$') { throw "bootstrap.ini has no UserInstallation entry: $bootstrap" }
  $text = [regex]::Replace($text, '(?m)^UserInstallation=.*$', ('UserInstallation=' + $Value), 1)
  Set-Content -LiteralPath $bootstrap -Value $text -Encoding utf8NoBOM
}

function Invoke-ProfileProbe {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][string]$CopiesParent,
    [ValidateSet('ABS_DEEP','ABS_DATA_SHALLOW','ABS_ROOT_SHALLOW','ORIGIN_ENV_DATA','ORIGIN_ENV_ROOT','BOOTSTRAP_ORIGIN_DATA','EXTERNAL_MATCHED_LONG')][string]$Strategy
  )

  $root = Join-Path $CopiesParent ("PDF Tunner LO Profile Strategy - $Name - With Spaces")
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  Copy-Item -LiteralPath $SourceRoot -Destination $root -Recurse -Force

  $sofficeCom = Join-Path $root 'tools\libreoffice\program\soffice.com'
  $sofficeExe = Join-Path $root 'tools\libreoffice\program\soffice.exe'
  $soffice = if (Test-Path -LiteralPath $sofficeCom -PathType Leaf) { $sofficeCom } else { $sofficeExe }
  $version = Invoke-CapturedProcess -FilePath $soffice -Arguments @('--version')

  $work = Join-Path $root 'data\profile-strategy\work'
  $temp = Join-Path $root 'data\profile-strategy\tmp'
  $out = Join-Path $work 'out'
  New-Item -ItemType Directory -Force -Path $work, $temp, $out | Out-Null
  $docx = Join-Path $work 'input.docx'
  $pdf = Join-Path $out 'input.pdf'
  New-MinimalDocx -Path $docx -Text "PDF_Tunner LibreOffice profile strategy probe: $Name"

  $profilePhysical = ''
  $profileArgument = ''
  $args = [System.Collections.Generic.List[string]]::new()

  switch ($Strategy) {
    'ABS_DEEP' {
      $profilePhysical = Join-Path $root 'data\profile-strategy\deep\nested\user-profile'
      New-Item -ItemType Directory -Force -Path $profilePhysical | Out-Null
      $profileArgument = Get-FileUri -Path $profilePhysical
      [void]$args.Add('-env:UserInstallation=' + $profileArgument)
    }
    'ABS_DATA_SHALLOW' {
      $profilePhysical = Join-Path $root 'data\lo'
      New-Item -ItemType Directory -Force -Path $profilePhysical | Out-Null
      $profileArgument = Get-FileUri -Path $profilePhysical
      [void]$args.Add('-env:UserInstallation=' + $profileArgument)
    }
    'ABS_ROOT_SHALLOW' {
      $profilePhysical = Join-Path $root 'p'
      New-Item -ItemType Directory -Force -Path $profilePhysical | Out-Null
      $profileArgument = Get-FileUri -Path $profilePhysical
      [void]$args.Add('-env:UserInstallation=' + $profileArgument)
    }
    'ORIGIN_ENV_DATA' {
      $profilePhysical = Join-Path $root 'data\lo'
      New-Item -ItemType Directory -Force -Path $profilePhysical | Out-Null
      $profileArgument = '$ORIGIN/../../../data/lo'
      [void]$args.Add('-env:UserInstallation=' + $profileArgument)
    }
    'ORIGIN_ENV_ROOT' {
      $profilePhysical = Join-Path $root 'p'
      New-Item -ItemType Directory -Force -Path $profilePhysical | Out-Null
      $profileArgument = '$ORIGIN/../../../p'
      [void]$args.Add('-env:UserInstallation=' + $profileArgument)
    }
    'BOOTSTRAP_ORIGIN_DATA' {
      $profilePhysical = Join-Path $root 'data\lo'
      New-Item -ItemType Directory -Force -Path $profilePhysical | Out-Null
      $profileArgument = '$ORIGIN/../../../data/lo'
      Set-BootstrapOriginProfile -Root $root -Value $profileArgument
    }
    'EXTERNAL_MATCHED_LONG' {
      $targetLength = (Join-Path $root 'data\profile-strategy\deep\nested\user-profile').Length
      $externalBase = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-lo-profile-length-$Name")
      Remove-Item -LiteralPath $externalBase -Recurse -Force -ErrorAction SilentlyContinue
      $profilePhysical = $externalBase
      $i = 0
      while ($profilePhysical.Length -lt $targetLength) {
        $profilePhysical = Join-Path $profilePhysical ("segment-$i-with-spaces")
        $i++
      }
      New-Item -ItemType Directory -Force -Path $profilePhysical | Out-Null
      $profileArgument = Get-FileUri -Path $profilePhysical
      [void]$args.Add('-env:UserInstallation=' + $profileArgument)
    }
  }

  foreach ($arg in @('--headless','--nologo','--convert-to','pdf','--outdir',$out,$docx)) { [void]$args.Add($arg) }
  $result = Invoke-CapturedProcess -FilePath $soffice -Arguments $args.ToArray() -EnvironmentOverrides @{ TEMP=$temp; TMP=$temp }
  $deadline = [DateTime]::UtcNow.AddSeconds(35)
  while ([DateTime]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $pdf -PathType Leaf)) { Start-Sleep -Milliseconds 250 }
  $ok = ($result.ExitCode -eq 0 -and (Test-Pdf -Path $pdf))
  $detail = (($result.Output -replace "`r|`n", ' ').Trim())
  $physicalLength = if ($profilePhysical) { $profilePhysical.Length } else { 0 }
  $argumentLength = if ($profileArgument) { $profileArgument.Length } else { 0 }
  return "PROBE_$Name=$(if ($ok) {'PASS'} else {'FAIL'})|STRATEGY=$Strategy|ROOT_LEN=$($root.Length)|PROFILE_PATH_LEN=$physicalLength|PROFILE_ARG_LEN=$argumentLength|VERSION_EXIT=$($version.ExitCode)|CONVERSION_EXIT=$($result.ExitCode)|PROFILE_ARG=$profileArgument|DETAIL=$detail"
}

$sourceRoot = [System.IO.Path]::GetFullPath($CandidateRoot)
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "Candidate root missing: $sourceRoot" }
$copiesParent = Join-Path (Split-Path -Parent $sourceRoot) 'profile-strategy-independent-copies'
Remove-Item -LiteralPath $copiesParent -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $copiesParent | Out-Null
$evidenceParent = Split-Path -Parent ([System.IO.Path]::GetFullPath($EvidencePath))
New-Item -ItemType Directory -Force -Path $evidenceParent | Out-Null

$specs = @(
  @{ Name='ABS_DEEP'; Strategy='ABS_DEEP' },
  @{ Name='ABS_DATA_SHALLOW'; Strategy='ABS_DATA_SHALLOW' },
  @{ Name='ABS_ROOT_SHALLOW'; Strategy='ABS_ROOT_SHALLOW' },
  @{ Name='ORIGIN_ENV_DATA'; Strategy='ORIGIN_ENV_DATA' },
  @{ Name='ORIGIN_ENV_ROOT'; Strategy='ORIGIN_ENV_ROOT' },
  @{ Name='BOOTSTRAP_ORIGIN_DATA'; Strategy='BOOTSTRAP_ORIGIN_DATA' },
  @{ Name='EXTERNAL_MATCHED_LONG'; Strategy='EXTERNAL_MATCHED_LONG' }
)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("LIBREOFFICE_VERSION=$LibreOfficeVersion")
$lines.Add("SOURCE_ROOT=$sourceRoot")
foreach ($spec in $specs) {
  $line = Invoke-ProfileProbe -Name $spec.Name -SourceRoot $sourceRoot -CopiesParent $copiesParent -Strategy $spec.Strategy
  $lines.Add($line)
  Write-Host $line
}
$lines | Set-Content -LiteralPath $EvidencePath -Encoding utf8
Write-Host "Profile strategy evidence: $EvidencePath"
