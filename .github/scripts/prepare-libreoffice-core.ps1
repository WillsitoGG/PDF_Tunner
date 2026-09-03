[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
    [Parameter(Mandatory = $true)][string]$LibreOfficeMsiUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$LibreOfficeMsiSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$libreOfficeRoot = Join-Path $toolsRoot 'libreoffice'
$binRoot = Join-Path $toolsRoot 'bin'
$temporaryParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$temporaryRoot = Join-Path $temporaryParent ("pdf-tunner-libreoffice-" + [Guid]::NewGuid().ToString('N'))
$msiPath = Join-Path $temporaryRoot "LibreOffice_$LibreOfficeVersion`_Win_x86-64.msi"
$administrativeRoot = Join-Path $temporaryRoot 'administrative-extract'

try {
    New-Item -ItemType Directory -Force -Path $toolsRoot, $binRoot, $temporaryRoot, $administrativeRoot | Out-Null

    Write-Host "Downloading pinned LibreOffice $LibreOfficeVersion MSI from The Document Foundation."
    Invoke-WebRequest -Uri $LibreOfficeMsiUrl -OutFile $msiPath -UseBasicParsing
    $msiHash = (Get-FileHash -LiteralPath $msiPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($msiHash -ne $LibreOfficeMsiSha256.ToLowerInvariant()) {
        throw "LibreOffice MSI SHA-256 mismatch: expected $($LibreOfficeMsiSha256.ToLowerInvariant()), got $msiHash."
    }

    Write-Host 'Performing MSI administrative extraction only; LibreOffice is not installed on the runner.'
    $msiArgs = @('/a', ('"' + $msiPath + '"'), '/qn', ('TARGETDIR="' + $administrativeRoot + '"'))
    $msi = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') -ArgumentList $msiArgs -Wait -PassThru
    if ($msi.ExitCode -notin @(0, 3010)) {
        throw "LibreOffice administrative extraction failed with msiexec exit code $($msi.ExitCode)."
    }

    $soffice = Get-ChildItem -LiteralPath $administrativeRoot -Recurse -Force -File -Filter 'soffice.exe' |
        Where-Object { $_.Directory.Name -eq 'program' } |
        Select-Object -First 1
    if (-not $soffice) { throw 'Administrative extraction completed but no program\soffice.exe was found.' }
    $installRoot = $soffice.Directory.Parent.FullName

    Remove-Item -LiteralPath $libreOfficeRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $libreOfficeRoot | Out-Null
    Get-ChildItem -LiteralPath $installRoot -Force | Copy-Item -Destination $libreOfficeRoot -Recurse -Force

    $sofficeCom = Join-Path $libreOfficeRoot 'program\soffice.com'
    $sofficeExe = Join-Path $libreOfficeRoot 'program\soffice.exe'
    foreach ($path in @($sofficeCom, $sofficeExe)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Packaged LibreOffice runtime file is missing: $path" }
    }

    $launcherSourcePath = (Resolve-Path -LiteralPath $LauncherSource).Path
    $launcher = Join-Path $binRoot 'unoconvert.exe'
    Remove-Item -LiteralPath $launcher -Force -ErrorAction SilentlyContinue
    & rustc.exe --edition 2021 -O -C strip=symbols $launcherSourcePath -o $launcher
    if ($LASTEXITCODE -ne 0) { throw "rustc failed to build the package-local unoconvert launcher with exit code $LASTEXITCODE." }
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw "Rust completed without producing $launcher." }

    $sofficeComHash = (Get-FileHash -LiteralPath $sofficeCom -Algorithm SHA256).Hash.ToLowerInvariant()
    $sofficeExeHash = (Get-FileHash -LiteralPath $sofficeExe -Algorithm SHA256).Hash.ToLowerInvariant()
    $launcherHash = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $libreOfficeRoot 'VERSION.txt') -Encoding ascii -Value $LibreOfficeVersion
    Set-Content -LiteralPath (Join-Path $libreOfficeRoot 'PROVENANCE.txt') -Encoding utf8 -Value @(
        'NAME=PDF_Tunner LibreOffice portable runtime',
        "LIBREOFFICE_VERSION=$LibreOfficeVersion",
        'LIBREOFFICE_ARCH=x86-64',
        "LIBREOFFICE_MSI_URL=$LibreOfficeMsiUrl",
        "LIBREOFFICE_MSI_SHA256=$msiHash",
        'EXTRACTION_MODE=MSI administrative extraction; LibreOffice is not installed on the runner',
        'UNOCONVERT_STRATEGY=tools/bin/unoconvert.exe package-relative native CLI compatibility shim -> tools/libreoffice/program/soffice.com (fallback soffice.exe)',
        'PATH_ORDER=tools/bin before tools/libreoffice/program before host PATH'
    )
    Set-Content -LiteralPath (Join-Path $libreOfficeRoot 'SHA256SUMS.txt') -Encoding ascii -Value @(
        "$sofficeComHash  program/soffice.com",
        "$sofficeExeHash  program/soffice.exe",
        "$launcherHash  ../bin/unoconvert.exe"
    )
    Set-Content -LiteralPath (Join-Path $binRoot 'UNOCONVERT_PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=PDF_Tunner unoconvert compatibility shim',
        'SOURCE=.github/scripts/unoconvert-launcher.rs',
        'BACKEND=tools/libreoffice/program/soffice.com; fallback soffice.exe',
        "LIBREOFFICE_VERSION=$LibreOfficeVersion",
        "SHA256=$launcherHash"
    )

    Write-Host "Staged LibreOffice $LibreOfficeVersion under $libreOfficeRoot"
    Write-Host "LibreOffice MSI SHA-256: $msiHash"
    Write-Host "unoconvert.exe SHA-256: $launcherHash"
}
finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}
