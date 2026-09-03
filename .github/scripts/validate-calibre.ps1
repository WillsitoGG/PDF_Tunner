[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$CalibreVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$CalibreMsiSha256,
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
        [hashtable]$EnvironmentOverrides = @{},
        [int]$TimeoutSeconds = 240
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
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { & taskkill.exe /PID $process.Id /T /F | Out-Null } catch { try { $process.Kill($true) } catch {} }
        throw "Process timed out after $TimeoutSeconds seconds: $FilePath $($Arguments -join ' ')"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout.Trim()
        StdErr = $stderr.Trim()
        Output = (($stdout + [Environment]::NewLine + $stderr).Trim())
    }
}

function Assert-Pdf {
    param([Parameter(Mandatory = $true)][string]$Path, [string]$Label = 'conversion')
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label produced no PDF: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -lt 500) { throw "$Label produced an implausibly small PDF." }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 5 -or [System.Text.Encoding]::ASCII.GetString($bytes, 0, 5) -ne '%PDF-') { throw "$Label output is not a PDF." }
}

function Assert-Epub {
    param([Parameter(Mandatory = $true)][string]$Path, [string]$Label = 'conversion')
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label produced no EPUB: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -lt 300) { throw "$Label produced an implausibly small EPUB." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $container = $archive.GetEntry('META-INF/container.xml')
        if ($null -eq $container -or $container.Length -lt 20) { throw "$Label EPUB has no META-INF/container.xml." }
        $opf = @($archive.Entries | Where-Object { $_.FullName -match '(?i)\.opf$' })
        if ($opf.Count -eq 0) { throw "$Label EPUB contains no OPF package document." }
    }
    finally { $archive.Dispose() }
}

function Assert-NoCalibreTempResidue {
    param([Parameter(Mandatory = $true)][string]$Root)
    $tempRoot = Join-Path $Root 'data\tmp\calibre'
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        $leftovers = @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue)
        if ($leftovers.Count -gt 0) {
            $leftovers | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
            throw 'Calibre launcher left per-invocation TEMP state behind.'
        }
    }
}

function Get-CalibreProcessesUnderRoot {
    param([Parameter(Mandatory = $true)][string]$Root)
    $prefix = [System.IO.Path]::GetFullPath((Join-Path $Root 'tools\calibre')).TrimEnd('\') + '\'
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $exe = [string]$_.ExecutablePath
        $cmd = [string]$_.CommandLine
        (($exe -and $exe.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) -or
         ($cmd -and $cmd.IndexOf($prefix, [System.StringComparison]::OrdinalIgnoreCase) -ge 0))
    })
}

function Assert-NoCalibreProcesses {
    param([Parameter(Mandatory = $true)][string]$Root)
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $remaining = @(Get-CalibreProcessesUnderRoot -Root $Root)
        if ($remaining.Count -eq 0) { return }
        Start-Sleep -Milliseconds 300
    } while ([DateTime]::UtcNow -lt $deadline)
    $remaining | Select-Object ProcessId, Name, ExecutablePath, CommandLine | Format-List
    throw 'Bundled Calibre processes remained after conversion.'
}

function Invoke-CalibreRoundTrip {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$Label)
    $launcher = Join-Path $Root 'tools\bin\ebook-convert.exe'
    $poppler = Join-Path $Root 'tools\poppler\Library\bin'
    $system32 = Join-Path $env:SystemRoot 'System32'
    $isolatedPath = @((Join-Path $Root 'tools\bin'), (Join-Path $Root 'tools\calibre'), $poppler, $system32, $env:SystemRoot) -join ';'
    $work = Join-Path $Root ("data\validation\calibre-$Label")
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $txt = Join-Path $work 'source.txt'
    $epub = Join-Path $work 'source.epub'
    $pdf = Join-Path $work 'source.pdf'
    $roundtripEpub = Join-Path $work 'roundtrip.epub'
    Set-Content -LiteralPath $txt -Encoding utf8 -Value @(
        'PDF_Tunner Calibre portable validation',
        '',
        "Relocatable ebook-convert round-trip: $Label",
        'Unicode proof: español, acción, información.'
    )
    $envOverride = @{ PATH = $isolatedPath }

    $txtToEpub = Invoke-CapturedProcess -FilePath $launcher -Arguments @($txt, $epub) -EnvironmentOverrides $envOverride
    if ($txtToEpub.ExitCode -ne 0) { throw "Calibre TXT->EPUB failed: $($txtToEpub.Output)" }
    Assert-Epub -Path $epub -Label 'Calibre TXT->EPUB'
    Assert-NoCalibreTempResidue -Root $Root
    Assert-NoCalibreProcesses -Root $Root

    $epubToPdf = Invoke-CapturedProcess -FilePath $launcher -Arguments @($epub, $pdf, '--pdf-add-toc', '--pdf-page-numbers') -EnvironmentOverrides $envOverride
    if ($epubToPdf.ExitCode -ne 0) { throw "Calibre EPUB->PDF failed: $($epubToPdf.Output)" }
    Assert-Pdf -Path $pdf -Label 'Calibre EPUB->PDF'
    Assert-NoCalibreTempResidue -Root $Root
    Assert-NoCalibreProcesses -Root $Root

    $pdfToEpubArgs = @(
        $pdf, $roundtripEpub,
        '--pdf-engine', 'pdftohtml',
        '--enable-heuristics',
        '--insert-blank-line',
        '--filter-css', 'font-family,color,background-color,margin-left,margin-right',
        '--output-profile', 'tablet'
    )
    $pdfToEpub = Invoke-CapturedProcess -FilePath $launcher -Arguments $pdfToEpubArgs -EnvironmentOverrides $envOverride
    if ($pdfToEpub.ExitCode -ne 0) { throw "Calibre PDF->EPUB via bundled pdftohtml failed: $($pdfToEpub.Output)" }
    Assert-Epub -Path $roundtripEpub -Label 'Calibre PDF->EPUB'
    Assert-NoCalibreTempResidue -Root $Root
    Assert-NoCalibreProcesses -Root $Root

    return [pscustomobject]@{ Epub = $epub; Pdf = $pdf; RoundtripEpub = $roundtripEpub }
}

function Invoke-StirlingMultipart {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$MimeType,
        [Parameter(Mandatory = $true)][string]$OutputFile
    )
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { throw "Windows curl.exe is unavailable: $curl" }
    $result = Invoke-CapturedProcess -FilePath $curl -Arguments @(
        '--silent', '--show-error', '--fail-with-body', '--connect-timeout', '15', '--max-time', '240',
        '--request', 'POST', '--form', ("fileInput=@{0};type={1}" -f $InputFile, $MimeType),
        '--output', $OutputFile, '--write-out', '%{http_code}', $Uri
    ) -TimeoutSeconds 260
    if ($result.ExitCode -ne 0 -or $result.StdOut -ne '200') {
        throw "Stirling API POST failed for $Uri (curl exit $($result.ExitCode), HTTP '$($result.StdOut)'). stderr: $($result.StdErr)"
    }
}

$portable = [System.IO.Path]::GetFullPath($PortableRoot)
$calibreRoot = Join-Path $portable 'tools\calibre'
$backend = Join-Path $calibreRoot 'ebook-convert.exe'
$launcher = Join-Path $portable 'tools\bin\ebook-convert.exe'
$poppler = Join-Path $portable 'tools\poppler\Library\bin\pdftohtml.exe'
$provenance = Join-Path $calibreRoot 'PROVENANCE.txt'
$checksums = Join-Path $calibreRoot 'SHA256SUMS.txt'
$versionFile = Join-Path $calibreRoot 'VERSION.txt'
$launcherProvenance = Join-Path $portable 'tools\bin\CALIBRE_PROVENANCE.txt'

foreach ($required in @($backend, $launcher, $poppler, $provenance, $checksums, $versionFile, $launcherProvenance)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required packaged Calibre/Poppler file is missing: $required" }
}
if ((Get-Content -LiteralPath $versionFile -Raw).Trim() -ne $CalibreVersion) { throw "Calibre VERSION.txt does not report $CalibreVersion." }
$metadata = Get-KeyValueMetadata -Path $provenance
if ($metadata.CALIBRE_VERSION -ne $CalibreVersion) { throw "Calibre provenance version mismatch: $($metadata.CALIBRE_VERSION)" }
if ($metadata.CALIBRE_MSI_SHA256.ToLowerInvariant() -ne $CalibreMsiSha256.ToLowerInvariant()) { throw 'Calibre provenance MSI hash mismatch.' }
if ((Get-PeMachine -Path $backend) -ne 0x8664) { throw 'Official packaged Calibre ebook-convert.exe is not AMD64.' }
if ((Get-PeMachine -Path $launcher) -ne 0x8664) { throw 'PDF_Tunner Calibre launcher is not AMD64.' }

$checksumText = Get-Content -LiteralPath $checksums -Raw
foreach ($entry in @(
    [pscustomobject]@{ Path = $backend; Relative = 'ebook-convert.exe' },
    [pscustomobject]@{ Path = $launcher; Relative = '../bin/ebook-convert.exe' }
)) {
    $match = [Regex]::Match($checksumText, ('(?im)^([0-9a-f]{64})\s+' + [Regex]::Escape($entry.Relative) + '\s*$'))
    if (-not $match.Success) { throw "Calibre SHA256SUMS.txt does not contain $($entry.Relative)." }
    $actual = (Get-FileHash -LiteralPath $entry.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $match.Groups[1].Value.ToLowerInvariant()) { throw "Packaged Calibre SHA-256 mismatch for $($entry.Relative)." }
}

$system32 = Join-Path $env:SystemRoot 'System32'
$isolatedPath = @((Join-Path $portable 'tools\bin'), $calibreRoot, (Join-Path $portable 'tools\poppler\Library\bin'), $system32, $env:SystemRoot) -join ';'
$where = Join-Path $system32 'where.exe'
$oldPath = $env:PATH
try {
    $env:PATH = $isolatedPath
    $resolved = @(& $where ebook-convert 2>$null | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    if ($LASTEXITCODE -ne 0 -or $resolved.Count -lt 1) { throw 'Isolated PATH did not resolve ebook-convert.' }
    $first = [System.IO.Path]::GetFullPath($resolved[0])
    if (-not $first.Equals([System.IO.Path]::GetFullPath($launcher), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Isolated PATH did not prefer the package-local Calibre launcher: $first"
    }
    $portablePrefix = $portable.TrimEnd('\') + '\'
    foreach ($path in $resolved) {
        if (-not [System.IO.Path]::GetFullPath($path).StartsWith($portablePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "ebook-convert resolved outside PDF_Tunner: $path"
        }
    }
    $versionResult = Invoke-CapturedProcess -FilePath $launcher -Arguments @('--version') -EnvironmentOverrides @{ PATH = $isolatedPath }
    if ($versionResult.ExitCode -ne 0 -or $versionResult.Output -notmatch ('(?i)\b' + [Regex]::Escape($CalibreVersion) + '\b')) {
        throw "Package-local ebook-convert did not report expected Calibre $CalibreVersion. Output: $($versionResult.Output)"
    }
}
finally { $env:PATH = $oldPath }

$hostCandidates = @(
    (Join-Path $env:APPDATA 'calibre'),
    (Join-Path $env:LOCALAPPDATA 'calibre'),
    (Join-Path $env:LOCALAPPDATA 'calibre-cache')
)
$hostBefore = @{}
foreach ($path in $hostCandidates) { $hostBefore[$path] = Test-Path -LiteralPath $path }

$roundTrip = Invoke-CalibreRoundTrip -Root $portable -Label 'direct'
foreach ($path in $hostCandidates) {
    if (-not $hostBefore[$path] -and (Test-Path -LiteralPath $path)) { throw "Calibre leaked state into the host profile: $path" }
}
foreach ($local in @('data\calibre\config', 'data\calibre\cache')) {
    if (-not (Test-Path -LiteralPath (Join-Path $portable $local) -PathType Container)) { throw "Calibre package-local state directory was not created: $local" }
}

if ($RequireRelocation) {
    $relocationRoot = Join-Path $env:RUNNER_TEMP ("PDF Tunner Calibre Relocation " + [Guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $relocationRoot 'tools\bin'), (Join-Path $relocationRoot 'tools\calibre'), (Join-Path $relocationRoot 'tools\poppler'), (Join-Path $relocationRoot 'data') | Out-Null
        Copy-Item -LiteralPath $launcher -Destination (Join-Path $relocationRoot 'tools\bin\ebook-convert.exe') -Force
        Copy-Item -LiteralPath $launcherProvenance -Destination (Join-Path $relocationRoot 'tools\bin\CALIBRE_PROVENANCE.txt') -Force
        Get-ChildItem -LiteralPath $calibreRoot -Force | Copy-Item -Destination (Join-Path $relocationRoot 'tools\calibre') -Recurse -Force
        Get-ChildItem -LiteralPath (Join-Path $portable 'tools\poppler') -Force | Copy-Item -Destination (Join-Path $relocationRoot 'tools\poppler') -Recurse -Force
        [void](Invoke-CalibreRoundTrip -Root $relocationRoot -Label 'relocated')
    }
    finally { Remove-Item -LiteralPath $relocationRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($BackendBaseUrl) {
    if (-not $BackendLogRoot) { throw '-BackendBaseUrl requires -BackendLogRoot.' }
    $backendWork = Join-Path $portable 'data\validation\calibre-backend'
    New-Item -ItemType Directory -Force -Path $backendWork | Out-Null
    $backendPdf = Join-Path $backendWork 'backend-ebook.pdf'
    Invoke-StirlingMultipart -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/ebook/pdf') -InputFile $roundTrip.Epub -MimeType 'application/epub+zip' -OutputFile $backendPdf
    Assert-Pdf -Path $backendPdf -Label 'Stirling eBook->PDF'
    $backendEpub = Join-Path $backendWork 'backend-pdf.epub'
    Invoke-StirlingMultipart -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/pdf/epub') -InputFile $backendPdf -MimeType 'application/pdf' -OutputFile $backendEpub
    Assert-Epub -Path $backendEpub -Label 'Stirling PDF->EPUB'
    Assert-NoCalibreTempResidue -Root $portable
    Assert-NoCalibreProcesses -Root $portable

    $logs = @(Get-ChildItem -LiteralPath $BackendLogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
    $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
    if ([string]::IsNullOrWhiteSpace($logText)) { throw 'No backend logs were available for Calibre acceptance.' }
    if ($logText -match '(?im)Missing dependency:\s*ebook-convert\b') { throw 'Stirling backend reported Missing dependency: ebook-convert.' }
    if ($logText -match '(?im)Disabling group:\s*Calibre\b') { throw 'Stirling backend disabled the Calibre group.' }
    if ($logText -notmatch '(?im)Running command:\s*ebook-convert\b') { throw 'Backend logs did not prove a real ebook-convert command execution.' }
}

Write-Host "PASS: Calibre $CalibreVersion MSI provenance/hash, AMD64 backend and launcher validated."
Write-Host 'PASS: package-first ebook-convert resolution, package-local config/cache/temp and process cleanup validated.'
Write-Host 'PASS: TXT->EPUB, EPUB->PDF and Stirling-shaped PDF->EPUB via bundled Poppler validated.'
if ($RequireRelocation) { Write-Host 'PASS: Calibre/Poppler toolchain relocates to a path containing spaces.' }
if ($BackendBaseUrl) { Write-Host 'PASS: real Stirling eBook->PDF and PDF->EPUB routes validated through packaged Calibre.' }
