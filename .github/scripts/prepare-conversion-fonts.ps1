[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$fontRelease = 'Noto Sans CJK 2.004'
$fontTag = 'Sans2.004'
$fonts = @(
    [pscustomobject]@{ Locale = 'SC'; Family = 'Noto Sans SC'; File = 'NotoSansSC-Regular.otf'; Sha256 = 'faa6c9df652116dde789d351359f3d7e5d2285a2b2a1f04a2d7244df706d5ea9' },
    [pscustomobject]@{ Locale = 'TC'; Family = 'Noto Sans TC'; File = 'NotoSansTC-Regular.otf'; Sha256 = '5bab0cb3c1cf89dde07c4a95a4054b195afbcfe784d69d75c340780712237537' },
    [pscustomobject]@{ Locale = 'HK'; Family = 'Noto Sans HK'; File = 'NotoSansHK-Regular.otf'; Sha256 = '8a43afea92bb58dfd9027bd7ac6f5b0b2662e2ffb3e7c1edc02c62b2b21924f1' },
    [pscustomobject]@{ Locale = 'JP'; Family = 'Noto Sans JP'; File = 'NotoSansJP-Regular.otf'; Sha256 = 'dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073' },
    [pscustomobject]@{ Locale = 'KR'; Family = 'Noto Sans KR'; File = 'NotoSansKR-Regular.otf'; Sha256 = '69975a0ac8472717870aefeab0a4d52739308d90856b9955313b2ad5e0148d68' }
)

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$libreOfficeRoot = Join-Path $portable 'tools\libreoffice'
$libreFontRoot = Join-Path $libreOfficeRoot 'share\fonts\truetype'
$metadataRoot = Join-Path $portable 'tools\fonts'
$libreProvenance = Join-Path $libreOfficeRoot 'PROVENANCE.txt'
$libreSha = Join-Path $libreOfficeRoot 'SHA256SUMS.txt'

foreach ($required in @($libreOfficeRoot, $libreFontRoot)) {
    if (-not (Test-Path -LiteralPath $required -PathType Container)) {
        throw "Accepted LibreOffice font root is missing: $required"
    }
}
foreach ($required in @($libreProvenance, $libreSha)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Accepted LibreOffice metadata file is missing: $required"
    }
}

# The official LibreOffice runtime already carries the common metric-compatible
# conversion fonts. Prove they are actually present before adding only the CJK
# gap rather than duplicating another complete Linux font stack.
$baselinePatterns = @(
    'Carlito*Regular*.ttf',
    'Caladea*Regular*.ttf',
    'DejaVuSans*.ttf',
    'LiberationSans*Regular*.ttf'
)
foreach ($pattern in $baselinePatterns) {
    $match = Get-ChildItem -LiteralPath $libreFontRoot -Recurse -Force -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $match) {
        throw "LibreOffice 26.2.5 does not contain the expected bundled conversion-font baseline matching '$pattern'."
    }
    Write-Host "Bundled LibreOffice font baseline: $($match.Name)"
}

New-Item -ItemType Directory -Force -Path $metadataRoot | Out-Null
$tempParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$tempRoot = Join-Path $tempParent ("pdf-tunner-conversion-fonts-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$shaLines = @()
$provenanceLines = @(
    'NAME=PDF_Tunner package-local conversion fonts',
    "NOTO_CJK_RELEASE=$fontRelease",
    "NOTO_CJK_TAG=$fontTag",
    'NOTO_CJK_LICENSE=OFL-1.1',
    'INSTALL_TARGET=tools/libreoffice/share/fonts/truetype',
    'STIRLING_PARITY=Stirling 2.14.3 Linux image installs fonts-noto-cjk and removes non-Regular Noto weights during image cleanup',
    'LIBREOFFICE_BASELINE=Carlito;Caladea;DejaVu Sans;Liberation Sans are supplied by the accepted official LibreOffice runtime',
    'LINUX_ONLY_FALLBACK_NOTE=fonts-freefont-ttf and fonts-terminus are Docker font fallback packages with no named Stirling source probe or feature gate; PDF_Tunner does not depend on host copies of them'
)

try {
    foreach ($font in $fonts) {
        $url = "https://raw.githubusercontent.com/notofonts/noto-cjk/$fontTag/Sans/SubsetOTF/$($font.Locale)/$($font.File)"
        $tempFile = Join-Path $tempRoot $font.File
        $destination = Join-Path $libreFontRoot $font.File
        Write-Host "Downloading $($font.Family) Regular from pinned Noto CJK tag $fontTag."
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
        $actual = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $font.Sha256) {
            throw "$($font.File) SHA-256 mismatch: expected $($font.Sha256), got $actual."
        }
        Copy-Item -LiteralPath $tempFile -Destination $destination -Force
        $installed = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($installed -ne $font.Sha256) {
            throw "$($font.File) changed while staging: expected $($font.Sha256), got $installed."
        }
        $shaLines += "$installed  ../libreoffice/share/fonts/truetype/$($font.File)"
        $provenanceLines += "NOTO_$($font.Locale)_FAMILY=$($font.Family)"
        $provenanceLines += "NOTO_$($font.Locale)_URL=$url"
        $provenanceLines += "NOTO_$($font.Locale)_SHA256=$installed"
        Write-Host "Staged $($font.File) SHA-256 $installed"
    }

    Set-Content -LiteralPath (Join-Path $metadataRoot 'VERSION.txt') -Encoding ascii -Value "$fontRelease Regular subsets (SC/TC/HK/JP/KR)"
    Set-Content -LiteralPath (Join-Path $metadataRoot 'PROVENANCE.txt') -Encoding utf8 -Value $provenanceLines
    Set-Content -LiteralPath (Join-Path $metadataRoot 'SHA256SUMS.txt') -Encoding ascii -Value $shaLines

    $existingLibreProvenance = @(Get-Content -LiteralPath $libreProvenance | Where-Object { $_ -notmatch '^PDF_TUNNER_CONVERSION_FONTS=' })
    $existingLibreProvenance += "PDF_TUNNER_CONVERSION_FONTS=$fontRelease Regular subsets SC/TC/HK/JP/KR; metadata=../fonts/PROVENANCE.txt"
    Set-Content -LiteralPath $libreProvenance -Encoding utf8 -Value $existingLibreProvenance

    $existingLibreSha = @(Get-Content -LiteralPath $libreSha | Where-Object { $_ -notmatch '(?i)share/fonts/truetype/NotoSans(SC|TC|HK|JP|KR)-Regular\.otf\s*$' })
    foreach ($line in $shaLines) {
        $existingLibreSha += ($line -replace '^([0-9a-f]+)\s+\.\./libreoffice/', '$1  ')
    }
    Set-Content -LiteralPath $libreSha -Encoding ascii -Value $existingLibreSha

    Write-Host "PASS: staged five package-local $fontRelease Regular CJK subsets without duplicating LibreOffice's existing Latin conversion-font baseline."
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
