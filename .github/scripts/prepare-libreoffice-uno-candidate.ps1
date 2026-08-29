param(
  [Parameter(Mandatory = $true)][string]$CandidateRoot,
  [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
  [Parameter(Mandatory = $true)][string]$LibreOfficeMsiUrl,
  [Parameter(Mandatory = $true)][string]$LibreOfficeMsiSha256
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

$root = [System.IO.Path]::GetFullPath($CandidateRoot)
$downloads = Join-Path $root '_downloads'
$adminExtract = Join-Path $root '_admin_extract'
$portable = Join-Path $root 'PDF_Tunner'
$tools = Join-Path $portable 'tools'
$libreOfficeTarget = Join-Path $tools 'libreoffice'
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
if (-not (Test-Path -LiteralPath $packagedSofficeCom -PathType Leaf)) {
  throw "Packaged LibreOffice is missing program\soffice.com: $packagedSofficeCom"
}

@(
  "LIBREOFFICE_VERSION=$LibreOfficeVersion",
  "LIBREOFFICE_MSI_URL=$LibreOfficeMsiUrl",
  "LIBREOFFICE_MSI_SHA256=$msiHash",
  'EXTRACTION_MODE=MSI administrative extraction; LibreOffice is not installed on the runner',
  'WINDOWS_UNOCONVERT_STRATEGY=package-local native CLI compatibility shim backed by bundled soffice',
  'TARGET_LAYOUT=tools/libreoffice + tools/bin/unoconvert.exe'
) | Set-Content -LiteralPath (Join-Path $portable 'LIBREOFFICE_WINDOWS_PROVENANCE.txt') -Encoding utf8

$msiHash | Set-Content -LiteralPath (Join-Path $libreOfficeTarget 'MSI_SHA256.txt') -Encoding ascii
$LibreOfficeVersion | Set-Content -LiteralPath (Join-Path $libreOfficeTarget 'VERSION.txt') -Encoding ascii

Remove-Item -LiteralPath $downloads -Recurse -Force
Remove-Item -LiteralPath $adminExtract -Recurse -Force

Write-Host 'PASS: LibreOffice Windows candidate payload prepared.'
Write-Host "Candidate portable root: $portable"
