param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
  [Parameter(Mandatory = $true)][string]$LibreOfficeMsiUrl,
  [Parameter(Mandatory = $true)][string]$LibreOfficeMsiSha256,
  [Parameter(Mandatory = $true)][string]$UnoServerVersion,
  [Parameter(Mandatory = $true)][string]$UnoServerWheelSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Hash {
  param([string]$Path, [string]$Expected)
  $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $Expected.ToLowerInvariant()) {
    throw "SHA-256 mismatch for $Path. Expected $Expected, got $actual."
  }
  return $actual
}

function Invoke-CapturedProcess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @()
  )
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FilePath
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  foreach ($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }

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

$root = [System.IO.Path]::GetFullPath($CandidateRoot)
$downloads = Join-Path $root '_downloads'
$adminExtract = Join-Path $root '_admin_extract'
$portable = Join-Path $root 'PDF_Tunner'
$tools = Join-Path $portable 'tools'
$libreOfficeTarget = Join-Path $tools 'libreoffice'
$unoTarget = Join-Path $tools 'unoserver'
$data = Join-Path $portable 'data'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $downloads, $adminExtract, $tools, $data | Out-Null

$msiPath = Join-Path $downloads "LibreOffice_$LibreOfficeVersion`_Win_x86-64.msi"
Write-Host "Downloading LibreOffice $LibreOfficeVersion from The Document Foundation..."
Invoke-WebRequest -Uri $LibreOfficeMsiUrl -OutFile $msiPath -UseBasicParsing
$msiHash = Assert-Hash -Path $msiPath -Expected $LibreOfficeMsiSha256

Write-Host 'Performing MSI administrative extraction (no product installation)...'
$msiArgs = @('/a', ('"' + $msiPath + '"'), '/qn', ('TARGETDIR="' + $adminExtract + '"'))
$msi = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
if ($msi.ExitCode -notin @(0, 3010)) {
  throw "LibreOffice administrative extraction failed with msiexec exit code $($msi.ExitCode)."
}

$soffice = Get-ChildItem -LiteralPath $adminExtract -Filter 'soffice.exe' -File -Recurse | Select-Object -First 1
if ($null -eq $soffice) { throw 'Administrative extraction completed but soffice.exe was not found.' }
if ($soffice.Directory.Name -ne 'program') {
  throw "Unexpected LibreOffice layout: soffice.exe parent is '$($soffice.Directory.FullName)'."
}
$installRoot = $soffice.Directory.Parent.FullName
Write-Host "Extracted LibreOffice root: $installRoot"
New-Item -ItemType Directory -Force -Path $libreOfficeTarget | Out-Null
Copy-Item -Path (Join-Path $installRoot '*') -Destination $libreOfficeTarget -Recurse -Force

$packagedSofficeExe = Join-Path $libreOfficeTarget 'program\soffice.exe'
$packagedSofficeCom = Join-Path $libreOfficeTarget 'program\soffice.com'
if (-not (Test-Path -LiteralPath $packagedSofficeExe -PathType Leaf)) {
  throw "Packaged LibreOffice is missing program\soffice.exe: $packagedSofficeExe"
}

Write-Host "Resolving unoserver $UnoServerVersion wheel metadata from PyPI..."
$metadataUri = "https://pypi.org/pypi/unoserver/$UnoServerVersion/json"
$metadata = Invoke-RestMethod -Uri $metadataUri
$wheel = @($metadata.urls | Where-Object { $_.filename -eq "unoserver-$UnoServerVersion-py3-none-any.whl" })
if ($wheel.Count -ne 1) { throw "Expected exactly one unoserver wheel, found $($wheel.Count)." }
if ($wheel[0].digests.sha256.ToLowerInvariant() -ne $UnoServerWheelSha256.ToLowerInvariant()) {
  throw 'PyPI metadata hash does not match pinned unoserver wheel SHA-256.'
}
$wheelPath = Join-Path $downloads $wheel[0].filename
Invoke-WebRequest -Uri $wheel[0].url -OutFile $wheelPath -UseBasicParsing
$wheelHash = Assert-Hash -Path $wheelPath -Expected $UnoServerWheelSha256

New-Item -ItemType Directory -Force -Path $unoTarget | Out-Null
$wheelZip = Join-Path $downloads 'unoserver-wheel.zip'
Copy-Item -LiteralPath $wheelPath -Destination $wheelZip -Force
Expand-Archive -LiteralPath $wheelZip -DestinationPath $unoTarget -Force

$versionBinary = if (Test-Path -LiteralPath $packagedSofficeCom -PathType Leaf) { $packagedSofficeCom } else { $packagedSofficeExe }
$versionResult = Invoke-CapturedProcess -FilePath $versionBinary -Arguments @('--version')
if ($versionResult.ExitCode -ne 0) {
  throw "Packaged soffice --version failed: $($versionResult.Output)"
}
$loVersionText = $versionResult.Output.Trim()
if ($loVersionText -notmatch [regex]::Escape($LibreOfficeVersion)) {
  throw "Packaged soffice version output does not contain pinned version $LibreOfficeVersion. Output: $loVersionText"
}

@(
  "LIBREOFFICE_VERSION=$LibreOfficeVersion",
  "LIBREOFFICE_MSI_URL=$LibreOfficeMsiUrl",
  "LIBREOFFICE_MSI_SHA256=$msiHash",
  "LIBREOFFICE_VERSION_OUTPUT=$loVersionText",
  "UNOSERVER_VERSION=$UnoServerVersion",
  "UNOSERVER_WHEEL_FILENAME=$($wheel[0].filename)",
  "UNOSERVER_WHEEL_URL=$($wheel[0].url)",
  "UNOSERVER_WHEEL_SHA256=$wheelHash",
  'EXTRACTION_MODE=MSI administrative extraction; LibreOffice is not installed on the runner',
  'TARGET_LAYOUT=tools/libreoffice + tools/unoserver'
) | Set-Content -LiteralPath (Join-Path $portable 'LIBREOFFICE_UNO_PROVENANCE.txt') -Encoding utf8

$msiHash | Set-Content -LiteralPath (Join-Path $libreOfficeTarget 'MSI_SHA256.txt') -Encoding ascii
$LibreOfficeVersion | Set-Content -LiteralPath (Join-Path $libreOfficeTarget 'VERSION.txt') -Encoding ascii
$wheelHash | Set-Content -LiteralPath (Join-Path $unoTarget 'WHEEL_SHA256.txt') -Encoding ascii
$UnoServerVersion | Set-Content -LiteralPath (Join-Path $unoTarget 'VERSION.txt') -Encoding ascii

Remove-Item -LiteralPath $downloads -Recurse -Force
Remove-Item -LiteralPath $adminExtract -Recurse -Force

Write-Host 'PASS: LibreOffice and unoserver candidate payload prepared.'
Write-Host "Candidate portable root: $portable"
