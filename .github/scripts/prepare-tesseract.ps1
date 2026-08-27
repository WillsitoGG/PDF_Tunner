[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('official-win64-nsis')]
    [string]$PackageVariant,

    [Parameter(Mandatory = $true)]
    [string]$DownloadUrl,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedSha256,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$TessdataCommit,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$EngBlobSha,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$SpaBlobSha,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$OsdBlobSha
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-GitBlobSha1 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $header = [System.Text.Encoding]::UTF8.GetBytes("blob $($bytes.Length)`0")
    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash([System.Security.Cryptography.HashAlgorithmName]::SHA1)
    try {
        $hash.AppendData($header)
        $hash.AppendData($bytes)
        return ([Convert]::ToHexString($hash.GetHashAndReset())).ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$toolsRoot = Join-Path $portable 'tools'
$tesseractRoot = Join-Path $toolsRoot 'tesseract'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-tesseract-" + [Guid]::NewGuid().ToString('N'))
$installer = Join-Path $tempRoot 'tesseract-win64.exe'
$extractRoot = Join-Path $tempRoot 'extract'

try {
    Remove-Item -LiteralPath $tesseractRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null

    Write-Host "Downloading official Tesseract $Version Win64 package from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $installer -UseBasicParsing

    $installerHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedHash = $ExpectedSha256.ToLowerInvariant()
    if ($installerHash -ne $expectedHash) {
        throw "Tesseract installer SHA-256 mismatch: expected $expectedHash, got $installerHash."
    }

    # The upstream Windows release is an NSIS package. Extract it as an archive
    # rather than executing it so the build cannot create registry, PATH or
    # uninstall state that the portable runtime might accidentally inherit.
    $sevenZip = Get-Command '7z.exe' -ErrorAction Stop
    & $sevenZip.Source x $installer ("-o{0}" -f $extractRoot) -y | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip failed to extract the official Tesseract NSIS package with exit code $LASTEXITCODE."
    }

    $candidateExe = Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -File -Filter 'tesseract.exe' |
        Where-Object {
            @(Get-ChildItem -LiteralPath $_.Directory.FullName -File -Filter 'libtesseract-*.dll' -ErrorAction SilentlyContinue).Count -gt 0
        } |
        Select-Object -First 1
    if (-not $candidateExe) {
        Write-Host 'Extracted Tesseract tree:'
        Get-ChildItem -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue |
            Select-Object -First 300 FullName, Length | Format-Table -AutoSize
        throw 'Official Tesseract package did not expose tesseract.exe beside libtesseract DLLs after archive extraction.'
    }

    $sourceRoot = $candidateExe.Directory.FullName
    New-Item -ItemType Directory -Force -Path $tesseractRoot | Out-Null
    Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $tesseractRoot -Recurse -Force

    $packagedExe = Join-Path $tesseractRoot 'tesseract.exe'
    if (-not (Test-Path -LiteralPath $packagedExe -PathType Leaf)) {
        throw "Packaged Tesseract executable is missing: $packagedExe"
    }

    $tessdataRoot = Join-Path $tesseractRoot 'tessdata'
    New-Item -ItemType Directory -Force -Path $tessdataRoot | Out-Null

    $models = @(
        [PSCustomObject]@{ Name = 'eng'; Blob = $EngBlobSha.ToLowerInvariant() },
        [PSCustomObject]@{ Name = 'spa'; Blob = $SpaBlobSha.ToLowerInvariant() },
        [PSCustomObject]@{ Name = 'osd'; Blob = $OsdBlobSha.ToLowerInvariant() }
    )

    foreach ($model in $models) {
        $destination = Join-Path $tessdataRoot "$($model.Name).traineddata"
        $url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/$TessdataCommit/$($model.Name).traineddata"
        Write-Host "Downloading pinned tessdata_fast model $($model.Name) from commit $TessdataCommit"
        Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
        $actualBlob = Get-GitBlobSha1 -Path $destination
        if ($actualBlob -ne $model.Blob) {
            throw "Git blob SHA mismatch for $($model.Name).traineddata: expected $($model.Blob), got $actualBlob."
        }
    }

    $oldTessdataPrefix = $env:TESSDATA_PREFIX
    try {
        $env:TESSDATA_PREFIX = $tessdataRoot
        $versionOutput = @(& $packagedExe --version 2>&1)
        if ($LASTEXITCODE -ne 0 -or $versionOutput.Count -eq 0) {
            throw "Packaged tesseract.exe --version failed with exit code $LASTEXITCODE."
        }
        $firstLine = ($versionOutput[0] | Out-String).Trim()
        if ($firstLine -notmatch ('^tesseract\s+' + [Regex]::Escape($Version) + '(\s|$)')) {
            throw "Packaged Tesseract version mismatch: expected $Version, got '$firstLine'."
        }
    }
    finally {
        if ($null -eq $oldTessdataPrefix) { Remove-Item Env:TESSDATA_PREFIX -ErrorAction SilentlyContinue } else { $env:TESSDATA_PREFIX = $oldTessdataPrefix }
    }

    $exeHash = (Get-FileHash -LiteralPath $packagedExe -Algorithm SHA256).Hash.ToLowerInvariant()
    $modelHashes = @{}
    foreach ($model in $models) {
        $path = Join-Path $tessdataRoot "$($model.Name).traineddata"
        $modelHashes[$model.Name] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    Set-Content -LiteralPath (Join-Path $tesseractRoot 'version.txt') -Encoding ascii -Value $Version
    Set-Content -LiteralPath (Join-Path $tesseractRoot 'PROVENANCE.txt') -Encoding ascii -Value @(
        'NAME=Tesseract OCR',
        "VERSION=$Version",
        "PACKAGE_VARIANT=$PackageVariant",
        "SOURCE_URL=$DownloadUrl",
        "INSTALLER_SHA256=$installerHash",
        'TESSDATA_REPOSITORY=https://github.com/tesseract-ocr/tessdata_fast',
        "TESSDATA_COMMIT=$($TessdataCommit.ToLowerInvariant())",
        'TESSDATA_LANGUAGES=eng,spa,osd',
        "TESSDATA_ENG_GIT_BLOB=$($EngBlobSha.ToLowerInvariant())",
        "TESSDATA_SPA_GIT_BLOB=$($SpaBlobSha.ToLowerInvariant())",
        "TESSDATA_OSD_GIT_BLOB=$($OsdBlobSha.ToLowerInvariant())"
    )
    Set-Content -LiteralPath (Join-Path $tesseractRoot 'SHA256SUMS.txt') -Encoding ascii -Value @(
        "$exeHash  tesseract.exe",
        "$($modelHashes['eng'])  tessdata/eng.traineddata",
        "$($modelHashes['spa'])  tessdata/spa.traineddata",
        "$($modelHashes['osd'])  tessdata/osd.traineddata"
    )

    $leakedInstallers = @(Get-ChildItem -LiteralPath $tesseractRoot -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^tesseract-ocr-w64-setup-.*\.exe$' -or $_.Name -ieq 'tesseract-win64.exe' })
    if ($leakedInstallers.Count -gt 0) {
        $leakedInstallers | Select-Object FullName, Length | Format-Table -AutoSize
        throw 'Downloaded Tesseract installer leaked into the portable tool directory.'
    }

    Write-Host "Staged Tesseract $Version at $tesseractRoot"
    Write-Host "Installer SHA-256: $installerHash"
    Write-Host "Tessdata commit: $TessdataCommit (eng, spa, osd)"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
