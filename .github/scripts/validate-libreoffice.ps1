[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$LibreOfficeMsiSha256,
    [string]$BackendBaseUrl,
    [string]$BackendLogRoot,
    [switch]$RequireRelocation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-PeMachine {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw "Not a PE/MZ executable: $Path" }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length) { throw "Invalid PE header offset in $Path" }
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) { throw "Missing PE signature in $Path" }
    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

function Get-KeyValueMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)
    $result = @{}
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        if ($line -match '^([^=]+)=(.*)$') { $result[$Matches[1]] = $Matches[2] }
    }
    return $result
}

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
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdoutTask.GetAwaiter().GetResult().Trim()
        StdErr = $stderrTask.GetAwaiter().GetResult().Trim()
        Output = (($stdoutTask.GetAwaiter().GetResult() + [Environment]::NewLine + $stderrTask.GetAwaiter().GetResult()).Trim())
    }
}

function Invoke-StirlingMultipart {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$InputContentType,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [hashtable]$Fields = @{}
    )

    $systemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot')
    if ([string]::IsNullOrWhiteSpace($systemRoot)) { throw 'SystemRoot is unavailable for the real Stirling API probe.' }
    $curl = Join-Path $systemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { throw "Windows curl.exe is unavailable for the real Stirling API probe: $curl" }

    $headers = "$OutputFile.headers"
    Remove-Item -LiteralPath $headers -Force -ErrorAction SilentlyContinue
    $arguments = @(
        '--silent', '--show-error', '--fail-with-body',
        '--connect-timeout', '15', '--max-time', '180',
        '--request', 'POST',
        '--form', ("fileInput=@{0};type={1}" -f $InputFile, $InputContentType)
    )
    foreach ($key in @($Fields.Keys | Sort-Object)) {
        $arguments += @('--form', ("{0}={1}" -f $key, [string]($Fields[$key])))
    }
    $arguments += @('--output', $OutputFile, '--dump-header', $headers, '--write-out', '%{http_code}', $Uri)
    $result = Invoke-CapturedProcess -FilePath $curl -Arguments $arguments
    $headerText = if (Test-Path -LiteralPath $headers -PathType Leaf) { Get-Content -LiteralPath $headers -Raw -ErrorAction SilentlyContinue } else { '' }
    if ($result.ExitCode -ne 0 -or $result.StdOut -ne '200') {
        throw "Stirling API POST failed for $Uri (curl exit $($result.ExitCode), HTTP '$($result.StdOut)'). curl stderr: $($result.StdErr). Response headers: $headerText"
    }
    Remove-Item -LiteralPath $headers -Force -ErrorAction SilentlyContinue
}

function Get-FileUri {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.Uri][System.IO.Path]::GetFullPath($Path)).AbsoluteUri
}

function Wait-File {
    param([Parameter(Mandatory = $true)][string]$Path, [int]$TimeoutSeconds = 20)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) { return $true }
        Start-Sleep -Milliseconds 200
    }
    return $false
}

function New-MinimalDocx {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ScratchRoot,
        [Parameter(Mandatory = $true)][string]$Text
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $scratch = Join-Path $ScratchRoot ("docx-source-" + [Guid]::NewGuid().ToString('N'))
    try {
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
        $escapedText = [System.Security.SecurityElement]::Escape($Text)
        @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>$escapedText</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
"@.Trim() | Set-Content -LiteralPath (Join-Path $scratch 'word\document.xml') -Encoding utf8
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFile]::CreateFromDirectory($scratch, $Path)
    }
    finally {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Pdf {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected PDF is missing: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -le 128) { throw "PDF is unexpectedly small: $Path" }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ([System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min(5, $bytes.Length)) -ne '%PDF-') {
        throw "Output is not a PDF: $Path"
    }
}

function Assert-Docx {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected DOCX is missing: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -le 128) { throw "DOCX is unexpectedly small: $Path" }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 4 -or $bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4b) { throw "Output is not a ZIP/DOCX: $Path" }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $document = $archive.GetEntry('word/document.xml')
        if ($null -eq $document -or $document.Length -le 24) { throw "DOCX has no coherent word/document.xml: $Path" }
    }
    finally {
        $archive.Dispose()
    }
}

function Get-LibreOfficeProcessesUnderRoot {
    param([Parameter(Mandatory = $true)][string]$Root)
    $programRoot = [System.IO.Path]::GetFullPath((Join-Path $Root 'tools\libreoffice\program')).TrimEnd('\') + '\'
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $executable = [string]$_.ExecutablePath
        $commandLine = [string]$_.CommandLine
        (($executable -and $executable.StartsWith($programRoot, [System.StringComparison]::OrdinalIgnoreCase)) -or
         ($commandLine -and $commandLine.IndexOf($programRoot, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
    })
}

function Assert-NoLibreOfficeProcesses {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    do {
        $remaining = @(Get-LibreOfficeProcessesUnderRoot -Root $Root)
        if ($remaining.Count -eq 0) { return }
        Start-Sleep -Milliseconds 300
    } while ([DateTime]::UtcNow -lt $deadline)
    $details = $remaining | ForEach-Object { "$($_.ProcessId):$($_.Name)" }
    throw "Bundled LibreOffice processes remained after ${Label}: $($details -join ', ')"
}

function Assert-CleanShimProfiles {
    param([Parameter(Mandatory = $true)][string]$Root)
    $profileRoot = Join-Path $Root 'p'
    if (Test-Path -LiteralPath $profileRoot -PathType Container) {
        $leftovers = @(Get-ChildItem -LiteralPath $profileRoot -Force -ErrorAction SilentlyContinue)
        if ($leftovers.Count -ne 0) { throw "unoconvert left package-local LibreOffice profile state: $($leftovers.FullName -join ', ')" }
    }
}

function Test-PackageResolution {
    param([Parameter(Mandatory = $true)][string]$Root)
    $binRoot = Join-Path $Root 'tools\bin'
    $programRoot = Join-Path $Root 'tools\libreoffice\program'
    $shim = Join-Path $binRoot 'unoconvert.exe'
    $soffice = Join-Path $programRoot 'soffice.com'
    $systemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot')
    if ([string]::IsNullOrWhiteSpace($systemRoot)) { throw 'SystemRoot is unavailable for isolated Windows command resolution.' }
    $system32 = Join-Path $systemRoot 'System32'
    $whereExe = Join-Path $system32 'where.exe'
    $oldPath = $env:PATH
    try {
        $env:PATH = "$binRoot;$programRoot;$system32;$systemRoot"
        $segments = @($env:PATH -split ';')
        $binIndex = [Array]::IndexOf([string[]]$segments, $binRoot)
        $programIndex = [Array]::IndexOf([string[]]$segments, $programRoot)
        if ($binIndex -lt 0 -or $programIndex -lt 0 -or $binIndex -ge $programIndex) {
            throw 'Portable PATH no longer puts tools/bin before tools/libreoffice/program.'
        }
        foreach ($probe in @(
            [pscustomobject]@{ Name = 'unoconvert'; ExpectedDirectory = $binRoot },
            [pscustomobject]@{ Name = 'soffice'; ExpectedDirectory = $programRoot }
        )) {
            $whereOutput = @(& $whereExe $probe.Name 2>&1)
            if ($LASTEXITCODE -ne 0 -or $whereOutput.Count -eq 0) { throw "where $($probe.Name) failed in the package-only PATH: $($whereOutput -join ' ')" }
            $expectedPrefix = [System.IO.Path]::GetFullPath($probe.ExpectedDirectory).TrimEnd('\') + '\'
            $resolved = @($whereOutput | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -and $_ -notmatch '^INFO:' })
            if ($resolved.Count -eq 0) { throw "where $($probe.Name) produced no executable paths." }
            foreach ($item in $resolved) {
                $full = [System.IO.Path]::GetFullPath($item)
                if (-not $full.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw "where $($probe.Name) resolved outside the PDF_Tunner package: $full"
                }
            }
        }
        $version = Invoke-CapturedProcess -FilePath $shim -Arguments @('--version') -EnvironmentOverrides @{ PATH = $env:PATH }
        if ($version.ExitCode -ne 0 -or $version.Output -notmatch [regex]::Escape($LibreOfficeVersion)) {
            throw "Package-local unoconvert --version failed: $($version.Output)"
        }
        $sofficeVersion = Invoke-CapturedProcess -FilePath $soffice -Arguments @('--version') -EnvironmentOverrides @{ PATH = $env:PATH }
        if ($sofficeVersion.ExitCode -ne 0 -or $sofficeVersion.Output -notmatch [regex]::Escape($LibreOfficeVersion)) {
            throw "Package-local soffice --version failed: $($sofficeVersion.Output)"
        }
    }
    finally {
        $env:PATH = $oldPath
    }
}

function Invoke-DirectSofficeConversion {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
    $soffice = Join-Path $Root 'tools\libreoffice\program\soffice.com'
    $work = Join-Path $Root ("data\tmp\libreoffice-direct-" + $Label)
    $profile = Join-Path $Root ("data\tmp\libreoffice-direct-profile-" + $Label)
    $nativeTemp = Join-Path $Root 'data\tmp\libreoffice'
    $out = Join-Path $work 'out'
    $input = Join-Path $work 'direct-input.docx'
    $pdf = Join-Path $out 'direct-input.pdf'
    try {
        New-Item -ItemType Directory -Force -Path $work, $profile, $nativeTemp, $out | Out-Null
        New-MinimalDocx -Path $input -ScratchRoot $work -Text "PDF_Tunner direct bundled soffice DOCX to PDF validation: $Label"
        $result = Invoke-CapturedProcess -FilePath $soffice -Arguments @(
            ('-env:UserInstallation=' + (Get-FileUri -Path $profile)),
            '--headless', '--nologo', '--convert-to', 'pdf', '--outdir', $out, $input
        ) -EnvironmentOverrides @{ TEMP = $nativeTemp; TMP = $nativeTemp }
        if ($result.ExitCode -ne 0) { throw "Bundled soffice DOCX to PDF failed ($Label): $($result.Output)" }
        if (-not (Wait-File -Path $pdf)) { throw "Bundled soffice exited successfully but produced no PDF ($Label): $($result.Output)" }
        Assert-Pdf -Path $pdf
    }
    finally {
        Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
    }
    Assert-NoLibreOfficeProcesses -Root $Root -Label "direct soffice $Label"
    return $pdf
}

function Invoke-UnoconvertContract {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
    $shim = Join-Path $Root 'tools\bin\unoconvert.exe'
    $work = Join-Path $Root ("data\tmp\libreoffice-shim-" + $Label)
    $input = Join-Path $work 'source.docx'
    $pdf = Join-Path $work 'requested-output.pdf'
    $docxEqual = Join-Path $work 'requested-output-equal.docx'
    $docxSplit = Join-Path $work 'requested-output-split.docx'
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    New-MinimalDocx -Path $input -ScratchRoot $work -Text "PDF_Tunner unoconvert contract validation: $Label"

    $toPdf = Invoke-CapturedProcess -FilePath $shim -Arguments @(
        '--host', '127.0.0.1', '--port', '2003', '--host-location', 'local', '--protocol', 'http',
        '--convert-to', 'pdf', $input, $pdf
    )
    if ($toPdf.ExitCode -ne 0) { throw "unoconvert split endpoint DOCX to PDF failed ($Label): $($toPdf.Output)" }
    if (-not (Wait-File -Path $pdf)) { throw "unoconvert split endpoint DOCX to PDF produced no requested output ($Label)." }
    Assert-Pdf -Path $pdf

    $toDocxEqual = Invoke-CapturedProcess -FilePath $shim -Arguments @(
        '--host=127.0.0.1', '--port=2003', '--host-location=local', '--protocol=http',
        '--convert-to=docx', '--input-filter=writer_pdf_import', $pdf, $docxEqual
    )
    if ($toDocxEqual.ExitCode -ne 0) { throw "unoconvert equals endpoint PDF to DOCX failed ($Label): $($toDocxEqual.Output)" }
    if (-not (Wait-File -Path $docxEqual)) { throw "unoconvert equals endpoint PDF to DOCX produced no requested output ($Label)." }
    Assert-Docx -Path $docxEqual

    $toDocxSplit = Invoke-CapturedProcess -FilePath $shim -Arguments @(
        '--host', '127.0.0.1', '--port', '2003', '--host-location', 'local', '--protocol', 'http',
        '--convert-to', 'docx', '--input-filter', 'writer_pdf_import', $pdf, $docxSplit
    )
    if ($toDocxSplit.ExitCode -ne 0) { throw "unoconvert split filter PDF to DOCX failed ($Label): $($toDocxSplit.Output)" }
    if (-not (Wait-File -Path $docxSplit)) { throw "unoconvert split filter PDF to DOCX produced no requested output ($Label)." }
    Assert-Docx -Path $docxSplit

    $localTemp = Join-Path $Root 'data\tmp\libreoffice'
    if (-not (Test-Path -LiteralPath $localTemp -PathType Container)) { throw "unoconvert did not create package-local LibreOffice TEMP/TMP: $localTemp" }
    Assert-CleanShimProfiles -Root $Root
    Assert-NoLibreOfficeProcesses -Root $Root -Label "unoconvert $Label"
    return [pscustomobject]@{ Pdf = $pdf; Docx = $docxEqual }
}

function Test-LibreOfficeRuntime {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
    Test-PackageResolution -Root $Root
    $null = Invoke-DirectSofficeConversion -Root $Root -Label $Label
    $shimResult = Invoke-UnoconvertContract -Root $Root -Label $Label
    return $shimResult
}

function Invoke-BackendConversionContract {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$LogRoot
    )
    if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) { throw "Backend log root is missing: $LogRoot" }
    $work = Join-Path $Root 'data\tmp\libreoffice-backend-contract'
    $input = Join-Path $work 'backend-source.docx'
    $pdf = Join-Path $work 'backend-office-to-pdf.pdf'
    $docx = Join-Path $work 'backend-pdf-to-docx.docx'
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    New-MinimalDocx -Path $input -ScratchRoot $work -Text 'PDF_Tunner real Stirling backend LibreOffice contract.'

    Invoke-StirlingMultipart -Uri ($BaseUrl.TrimEnd('/') + '/api/v1/convert/file/pdf') `
        -InputFile $input `
        -InputContentType 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' `
        -OutputFile $pdf
    Assert-Pdf -Path $pdf

    Invoke-StirlingMultipart -Uri ($BaseUrl.TrimEnd('/') + '/api/v1/convert/pdf/word') `
        -InputFile $pdf `
        -InputContentType 'application/pdf' `
        -OutputFile $docx `
        -Fields @{ outputFormat = 'docx' }
    Assert-Docx -Path $docx

    $logs = @(Get-ChildItem -LiteralPath $LogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
    if ($logs.Count -eq 0) { throw 'No package-local backend logs were available to prove LibreOffice and unoconvert dependency acceptance.' }
    $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
    foreach ($forbidden in @(
        '(?im)Missing dependency:\s*soffice\b',
        '(?im)Missing dependency:\s*unoconvert\b',
        '(?im)Disabling group:\s*LibreOffice\b',
        '(?im)Disabling group:\s*Unoconvert\b',
        '(?im)Unoconvert command failed'
    )) {
        if ($logText -match $forbidden) { throw "Stirling backend rejected the package-local LibreOffice/unoconvert dependency: $forbidden" }
    }
    if ($logText -notmatch '(?im)Running command:\s+unoconvert(?:\.exe)?\b') {
        throw 'The real Stirling backend API calls did not log an unoconvert command; a soffice fallback is not sufficient for this gate.'
    }
    $localTemp = Join-Path $Root 'data\tmp\libreoffice'
    if (-not (Test-Path -LiteralPath $localTemp -PathType Container)) { throw "Backend unoconvert contract did not retain package-local LibreOffice TEMP/TMP: $localTemp" }
    Assert-CleanShimProfiles -Root $Root
    Assert-NoLibreOfficeProcesses -Root $Root -Label 'real Stirling backend operations'
    Write-Host 'PASS: real Stirling backend Office->PDF and PDF->DOCX routes used accepted package-local unoconvert.'
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$libreOfficeRoot = Join-Path $portable 'tools\libreoffice'
$binRoot = Join-Path $portable 'tools\bin'
$sofficeCom = Join-Path $libreOfficeRoot 'program\soffice.com'
$sofficeExe = Join-Path $libreOfficeRoot 'program\soffice.exe'
$shim = Join-Path $binRoot 'unoconvert.exe'
$provenance = Join-Path $libreOfficeRoot 'PROVENANCE.txt'
$versionFile = Join-Path $libreOfficeRoot 'VERSION.txt'
$shaSums = Join-Path $libreOfficeRoot 'SHA256SUMS.txt'
$shimProvenance = Join-Path $binRoot 'UNOCONVERT_PROVENANCE.txt'
foreach ($path in @($sofficeCom, $sofficeExe, $shim, $provenance, $versionFile, $shaSums, $shimProvenance)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required LibreOffice portable file is missing: $path" }
}
if ((Get-PeMachine -Path $sofficeExe) -ne 0x8664) { throw 'Bundled soffice.exe is not AMD64.' }
if ((Get-PeMachine -Path $shim) -ne 0x8664) { throw 'Bundled unoconvert.exe shim is not AMD64.' }
if ((Get-Content -LiteralPath $versionFile -Raw).Trim() -ne $LibreOfficeVersion) { throw 'LibreOffice VERSION.txt does not match the requested pin.' }

$metadata = Get-KeyValueMetadata -Path $provenance
foreach ($required in (@{
    'LIBREOFFICE_VERSION' = $LibreOfficeVersion
    'LIBREOFFICE_ARCH' = 'x86-64'
    'LIBREOFFICE_MSI_SHA256' = $LibreOfficeMsiSha256.ToLowerInvariant()
}).GetEnumerator()) {
    if (-not $metadata.ContainsKey($required.Key)) { throw "LibreOffice provenance is missing $($required.Key)." }
    if ($metadata[$required.Key].ToLowerInvariant() -ne $required.Value.ToLowerInvariant()) {
        throw "LibreOffice provenance mismatch for $($required.Key): expected '$($required.Value)', got '$($metadata[$required.Key])'."
    }
}
if ($metadata['EXTRACTION_MODE'] -notmatch 'administrative extraction') { throw 'LibreOffice provenance does not prove MSI administrative extraction.' }
if ($metadata['UNOCONVERT_STRATEGY'] -notmatch 'package-relative native CLI compatibility shim') { throw 'LibreOffice provenance does not describe the required native unoconvert shim.' }

$shaText = Get-Content -LiteralPath $shaSums -Raw
foreach ($item in @(
    @{ Path = $sofficeCom; Name = 'program/soffice.com' },
    @{ Path = $sofficeExe; Name = 'program/soffice.exe' },
    @{ Path = $shim; Name = '../bin/unoconvert.exe' }
)) {
    $hash = (Get-FileHash -LiteralPath $item.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($shaText -notmatch "(?im)^$hash\s+$([Regex]::Escape($item.Name))\s*$") { throw "SHA256SUMS.txt does not contain the packaged hash for $($item.Name)." }
}

$shimMetadata = Get-KeyValueMetadata -Path $shimProvenance
if ($shimMetadata['LIBREOFFICE_VERSION'] -ne $LibreOfficeVersion) { throw 'UNOCONVERT_PROVENANCE.txt does not match the LibreOffice version.' }
if ($shimMetadata['SHA256'].ToLowerInvariant() -ne (Get-FileHash -LiteralPath $shim -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'UNOCONVERT_PROVENANCE.txt does not match unoconvert.exe.' }

$null = Test-LibreOfficeRuntime -Root $portable -Label 'source'
Write-Host 'PASS: bundled direct soffice and native unoconvert DOCX->PDF / PDF->DOCX contracts succeeded.'

if ($RequireRelocation) {
    $temporaryParent = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
    $relocationContainer = Join-Path $temporaryParent ("PDF_Tunner LibreOffice relocation " + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $rootA = Join-Path $relocationContainer 'Portable Tree With Spaces'
    $rootB = Join-Path $relocationContainer 'Portable Tree Moved With Spaces'
    $currentRoot = $portable
    try {
        New-Item -ItemType Directory -Force -Path $relocationContainer | Out-Null
        Move-Item -LiteralPath $portable -Destination $rootA
        $currentRoot = $rootA
        $null = Test-LibreOfficeRuntime -Root $rootA -Label 'relocated-a'
        Move-Item -LiteralPath $rootA -Destination $rootB
        $currentRoot = $rootB
        $null = Test-LibreOfficeRuntime -Root $rootB -Label 'relocated-b'
        Write-Host "PASS: LibreOffice runtime was used, moved, and reused at normal Windows paths with spaces: '$rootA' -> '$rootB'."
    }
    finally {
        if (-not (Test-Path -LiteralPath $portable -PathType Container)) {
            if (Test-Path -LiteralPath $rootB -PathType Container) {
                Move-Item -LiteralPath $rootB -Destination $portable
            }
            elseif (Test-Path -LiteralPath $rootA -PathType Container) {
                Move-Item -LiteralPath $rootA -Destination $portable
            }
            elseif ((Test-Path -LiteralPath $currentRoot -PathType Container) -and $currentRoot -ne $portable) {
                Move-Item -LiteralPath $currentRoot -Destination $portable
            }
        }
        if (Test-Path -LiteralPath $portable -PathType Container) {
            Remove-Item -LiteralPath $relocationContainer -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($BackendBaseUrl) -or -not [string]::IsNullOrWhiteSpace($BackendLogRoot)) {
    if ([string]::IsNullOrWhiteSpace($BackendBaseUrl) -or [string]::IsNullOrWhiteSpace($BackendLogRoot)) {
        throw 'BackendBaseUrl and BackendLogRoot must be supplied together for the real Stirling backend gate.'
    }
    Invoke-BackendConversionContract -Root $portable -BaseUrl $BackendBaseUrl -LogRoot $BackendLogRoot
}

Write-Host "PASS: LibreOffice $LibreOfficeVersion portable validation completed."
