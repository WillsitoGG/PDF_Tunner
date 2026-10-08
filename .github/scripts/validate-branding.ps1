[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [string]$BackendBaseUrl
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-ZipText {
    param(
        [Parameter(Mandatory = $true)][System.IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory = $true)][string]$Suffix
    )
    $entry = $Archive.Entries | Where-Object {
        $_.FullName -eq $Suffix -or $_.FullName.EndsWith('/' + $Suffix)
    } | Select-Object -First 1
    if ($null -eq $entry) { throw "JAR entry missing: $Suffix" }
    $reader = [System.IO.StreamReader]::new($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Get-ZipEntryHash {
    param(
        [Parameter(Mandatory = $true)][System.IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory = $true)][string]$Suffix
    )
    $entry = $Archive.Entries | Where-Object {
        $_.FullName -eq $Suffix -or $_.FullName.EndsWith('/' + $Suffix)
    } | Select-Object -First 1
    if ($null -eq $entry) { throw "JAR entry missing: $Suffix" }
    $stream = $entry.Open()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Assert-FrontendBranding {
    param([Parameter(Mandatory = $true)][string]$DistRoot)

    $indexPath = Join-Path $DistRoot 'index.html'
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        throw "Tauri frontend dist index is missing: $indexPath"
    }
    $index = Get-Content -LiteralPath $indexPath -Raw
    if ($index -notmatch '<title>PDF_Tunner</title>') {
        throw 'Built Tauri frontend index does not contain <title>PDF_Tunner</title>.'
    }
    if ($index -notmatch 'property="og:site_name"\s+content="PDF_Tunner"') {
        throw 'Built Tauri frontend index does not expose og:site_name=PDF_Tunner.'
    }
    if ($index -notmatch 'pdf-tunner/icon-light\.svg') {
        throw 'Built Tauri frontend index does not reference the PDF_Tunner favicon.'
    }

    foreach ($relative in @(
        'pdf-tunner/icon-light.svg',
        'pdf-tunner/icon-dark.svg',
        'pdf-tunner/wordmark-black.svg',
        'pdf-tunner/wordmark-grey.svg',
        'pdf-tunner/wordmark-white.svg'
    )) {
        $path = Join-Path $DistRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Built Tauri frontend branding asset is missing: $relative"
        }
        if ((Get-Content -LiteralPath $path -Raw) -notmatch 'PDF_Tunner') {
            throw "Built Tauri frontend branding asset does not identify PDF_Tunner: $relative"
        }
    }

    foreach ($manifestName in @('manifest.json','manifest-classic.json')) {
        $path = Join-Path $DistRoot $manifestName
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Built Tauri frontend manifest is missing: $manifestName"
        }
        $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($manifest.name -ne 'PDF_Tunner' -or $manifest.short_name -ne 'PDF_Tunner') {
            throw "Built Tauri frontend manifest is not PDF_Tunner branded: $manifestName"
        }
        if (@($manifest.icons).Count -lt 1 -or $manifest.icons[0].src -ne 'pdf-tunner/icon-light.svg') {
            throw "Built Tauri frontend manifest does not reference the PDF_Tunner icon: $manifestName"
        }
    }

    Write-Host 'PASS: Tauri frontend dist contains PDF_Tunner title, metadata, manifests and visual assets.'
}

# Guard actual React lockups; only checking index.html/assets was insufficient
# (a real Windows 10 VM still displayed Stirling marks after Run #129).
$reactLogo = Get-Content -LiteralPath './frontend/editor/src/core/ui/Logo.tsx' -Raw
$brandMark = Get-Content -LiteralPath './frontend/editor/src/core/components/shared/BrandMark.tsx' -Raw
$portableUpdateHook = Get-Content -LiteralPath './frontend/editor/src/desktop/hooks/useDesktopUpdatePopup.ts' -Raw
$portableMode = Get-Content -LiteralPath './frontend/editor/src-tauri/src/commands/platform.rs' -Raw
$localWalletGate = Get-Content -LiteralPath './frontend/editor/src/desktop/hooks/walletApiEnabled.ts' -Raw
if ($reactLogo -match '@app/assets/brand/branding-logo' -or $reactLogo -notmatch 'pdf-tunner/wordmark-black\.svg' -or $reactLogo -notmatch 'alt = "PDF_Tunner"') {
    throw 'Shared React lockup still uses original Stirling artwork/alt text.'
}
if ($brandMark -match 'aria-label="Stirling"' -or $brandMark -notmatch 'pdf-tunner/icon-light\.svg') {
    throw 'Header app switcher still uses Stirling SVG or lacks the PDF_Tunner icon.'
}
if ($portableUpdateHook -notmatch 'is_pdf_tunner_portable' -or $portableMode -notmatch 'pub fn is_pdf_tunner_portable') {
    throw 'PDF_Tunner portable update guard is missing; official Stirling updates might be queried.'
}
if ($localWalletGate -notmatch 'getCurrentMode' -or $localWalletGate -notmatch '"saas"') {
    throw 'The portable local backend might receive the unsupported PAYG wallet request.'
}
$searchSource = Get-Content -LiteralPath './frontend/editor/src/core/components/shared/superSearch/SuperSearch.tsx' -Raw
$serviceSource = Get-Content -LiteralPath './frontend/editor/src/core/services/updateService.ts' -Raw
$brandStyle = Get-Content -LiteralPath './frontend/editor/src/core/components/shared/BrandMark.css' -Raw
if ($searchSource -notmatch 'PDF_Tunner' -or $searchSource -notmatch 'superSearch.placeholder') { throw 'Visible global search not branded.' }
if (($serviceSource | Select-String -Pattern 'if \(await isPortablePdfTunner\(\)\)' -AllMatches).Matches.Count -ne 3) { throw 'Portable upstream update service is not blocked everywhere.' }
if ($brandStyle -notmatch 'sui-brandmark__chevron' -or $brandStyle -notmatch 'filter: invert\(1\)') { throw 'App-switch cue or dark-theme logo contrast missing.' }
$portableOnboarding = Get-Content -LiteralPath './frontend/editor/src/desktop/components/DesktopOnboardingModal.tsx' -Raw
$portableGeneral = Get-Content -LiteralPath './frontend/editor/src/desktop/components/shared/config/configSections/GeneralSection.tsx' -Raw
$portableConnection = Get-Content -LiteralPath './frontend/editor/src/desktop/components/ConnectionSettings.tsx' -Raw
if ($portableOnboarding -notmatch 'is_pdf_tunner_portable' -or $portableOnboarding -notmatch 'useState\(false\)') { throw 'Portable onboarding must remain hidden during native flag detection.' }
if ($portableGeneral -notmatch 'hideUpdateSection=\{' -or $portableGeneral -notmatch '!isPortable && <DefaultAppSettings') { throw 'Portable update and default-handler UI must be hidden.' }
if ($portableConnection -notmatch '!isPortable && <Button onClick=\{handleSignIn\}') { throw 'Portable local sign-in control must be hidden.' }
Write-Host 'PASS: runtime React logo paths, native portable update guard and PAYG route guard are present.'

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$exe = Join-Path $portable 'PDF_Tunner.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "PDF_Tunner.exe missing: $exe" }

$configPath = (Resolve-Path -LiteralPath './frontend/editor/src-tauri/tauri.pdf-tunner.conf.json').Path
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($config.productName -ne 'PDF_Tunner') { throw 'Tauri productName is not PDF_Tunner.' }
if ($config.mainBinaryName -ne 'PDF_Tunner') { throw 'Tauri mainBinaryName is not PDF_Tunner.' }
if ($config.app.windows[0].title -ne 'PDF_Tunner') { throw 'Tauri main-window title is not PDF_Tunner.' }
if ($config.identifier -ne 'com.willsitogg.pdf-tunner') { throw "Unexpected PDF_Tunner Tauri identifier: $($config.identifier)" }
if (@($config.bundle.icon) -notcontains 'icons/pdf-tunner.ico') { throw 'Tauri bundle icon does not use icons/pdf-tunner.ico.' }

$sourceIco = (Resolve-Path -LiteralPath './frontend/editor/src-tauri/icons/pdf-tunner.ico').Path
$icoBytes = [System.IO.File]::ReadAllBytes($sourceIco)
if ($icoBytes.Length -lt 1024 -or $icoBytes[0] -ne 0 -or $icoBytes[1] -ne 0 -or $icoBytes[2] -ne 1 -or $icoBytes[3] -ne 0) {
    throw "Generated PDF_Tunner source icon is not a valid ICO: $sourceIco"
}

Add-Type -AssemblyName System.Drawing
$associatedIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($exe)
if ($null -eq $associatedIcon) { throw 'PDF_Tunner.exe has no extractable Windows icon.' }
try {
    if ($associatedIcon.Width -lt 16 -or $associatedIcon.Height -lt 16) {
        throw "PDF_Tunner.exe icon is unexpectedly small: $($associatedIcon.Width)x$($associatedIcon.Height)"
    }
}
finally {
    $associatedIcon.Dispose()
}

# The desktop product intentionally has two different web payloads:
# - frontend/editor/dist is the React frontend embedded by Tauri in PDF_Tunner.exe;
# - libs/*.jar is the backend-only Spring payload, whose root is api-landing.html.
$frontendDist = (Resolve-Path -LiteralPath './frontend/editor/dist').Path
Assert-FrontendBranding -DistRoot $frontendDist

$jar = $null
foreach ($candidate in @(Get-ChildItem -LiteralPath (Join-Path $portable 'libs') -File -Filter '*.jar' -ErrorAction Stop)) {
    $probe = [System.IO.Compression.ZipFile]::OpenRead($candidate.FullName)
    try {
        if ($probe.Entries | Where-Object { $_.FullName.EndsWith('/static/index.html') } | Select-Object -First 1) {
            $jar = $candidate
            break
        }
    }
    finally {
        $probe.Dispose()
    }
}
if ($null -eq $jar) { throw 'Could not locate the packaged backend JAR containing static/index.html.' }

$archive = [System.IO.Compression.ZipFile]::OpenRead($jar.FullName)
try {
    $index = Read-ZipText -Archive $archive -Suffix 'static/index.html'
    if ($index -notmatch '<title>PDF_Tunner - API Server</title>') {
        throw 'Backend-only JAR root is not the PDF_Tunner API landing page.'
    }
    if ($index -notmatch '/pdf-tunner/wordmark-black\.svg') {
        throw 'Backend-only JAR root does not reference the PDF_Tunner wordmark.'
    }

    foreach ($asset in @(
        'static/pdf-tunner/icon-light.svg',
        'static/pdf-tunner/icon-dark.svg',
        'static/pdf-tunner/wordmark-black.svg',
        'static/pdf-tunner/wordmark-grey.svg',
        'static/pdf-tunner/wordmark-white.svg'
    )) {
        $content = Read-ZipText -Archive $archive -Suffix $asset
        if ($content -notmatch 'PDF_Tunner') { throw "Packaged backend branding asset does not identify PDF_Tunner: $asset" }
    }

    $mobile = Read-ZipText -Archive $archive -Suffix 'static/mobile-upload.html'
    if ($mobile -notmatch '<title>PDF_Tunner - Mobile Upload</title>' -or $mobile -notmatch 'PDF_Tunner &middot;') {
        throw 'Packaged mobile upload surface is not PDF_Tunner branded.'
    }

    $apiLanding = Read-ZipText -Archive $archive -Suffix 'static/api-landing.html'
    if ($apiLanding -notmatch '<title>PDF_Tunner - API Server</title>' -or $apiLanding -notmatch '/pdf-tunner/wordmark-black\.svg') {
        throw 'Packaged API landing surface is not PDF_Tunner branded.'
    }

    $signatureSourceHash = (Get-FileHash -LiteralPath './app/core/src/main/resources/static/images/signature.png' -Algorithm SHA256).Hash.ToLowerInvariant()
    $signatureJarHash = Get-ZipEntryHash -Archive $archive -Suffix 'static/images/signature.png'
    if ($signatureSourceHash -ne $signatureJarHash) { throw 'Packaged cert-sign logo does not match generated PDF_Tunner signature asset.' }

    $wordmarkSourceHash = (Get-FileHash -LiteralPath './app/core/src/main/resources/static/images/stirling-logo-white.png' -Algorithm SHA256).Hash.ToLowerInvariant()
    $wordmarkJarHash = Get-ZipEntryHash -Archive $archive -Suffix 'static/images/stirling-logo-white.png'
    if ($wordmarkSourceHash -ne $wordmarkJarHash) { throw 'Packaged signing wordmark does not match generated PDF_Tunner wordmark asset.' }
}
finally {
    $archive.Dispose()
}

if (-not [string]::IsNullOrWhiteSpace($BackendBaseUrl)) {
    $base = $BackendBaseUrl.TrimEnd('/')

    $appConfig = Invoke-RestMethod -Uri "$base/api/v1/config/app-config" -Method Get -TimeoutSec 30
    if ($appConfig.appNameNavbar -ne 'PDF_Tunner') {
        throw "Live app-config appNameNavbar is not PDF_Tunner: '$($appConfig.appNameNavbar)'"
    }

    $root = Invoke-WebRequest -Uri "$base/" -UseBasicParsing -TimeoutSec 30
    if ($root.StatusCode -ne 200 -or $root.Content -notmatch '<title>PDF_Tunner - API Server</title>') {
        throw 'Live backend root did not serve the PDF_Tunner API landing page.'
    }

    $brandAsset = Invoke-WebRequest -Uri "$base/pdf-tunner/icon-light.svg" -UseBasicParsing -TimeoutSec 30
    if ($brandAsset.StatusCode -ne 200 -or $brandAsset.Content -notmatch 'PDF_Tunner') {
        throw 'Live backend did not serve the PDF_Tunner branding asset.'
    }

    Write-Host 'PASS: live backend exposes PDF_Tunner app-config, API landing identity and branding assets.'
}

Write-Host "PDF_Tunner executable: $exe"
Write-Host "PDF_Tunner Tauri frontend dist: $frontendDist"
Write-Host "PDF_Tunner packaged backend JAR: $($jar.FullName)"
Write-Host 'PASS: PDF_Tunner frontend, backend surfaces, signing logos and Windows executable branding are present in the assembled portable product.'
