[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedArchiveSha256,
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
        [string]$WorkingDirectory
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
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
        StdOut = $stdout.Trim()
        StdErr = $stderr.Trim()
        Output = (($stdout + [Environment]::NewLine + $stderr).Trim())
    }
}

function Assert-Pdf {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label produced no PDF: $Path" }
    $info = Get-Item -LiteralPath $Path
    if ($info.Length -lt 1000) { throw "$Label produced an implausibly small PDF: $($info.Length) bytes." }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 5 -or [System.Text.Encoding]::ASCII.GetString($bytes, 0, 5) -ne '%PDF-') {
        throw "$Label output is not a PDF."
    }
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
        '--silent', '--show-error', '--fail-with-body', '--connect-timeout', '15', '--max-time', '180',
        '--request', 'POST', '--form', ("fileInput=@{0};type={1}" -f $InputFile, $MimeType),
        '--output', $OutputFile, '--write-out', '%{http_code}', $Uri
    )
    if ($result.ExitCode -ne 0 -or $result.StdOut -ne '200') {
        throw "Stirling API POST failed for $Uri (curl exit $($result.ExitCode), HTTP '$($result.StdOut)'). stderr: $($result.StdErr)"
    }
    Assert-Pdf -Path $OutputFile -Label "Stirling route $Uri"
}

function Test-WeasyPrintRuntime {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$ExpectedVersion,
        [Parameter(Mandatory = $true)][string]$FixtureHtml,
        [Parameter(Mandatory = $true)][string]$OutputPdf
    )
    $launcherPath = Join-Path $Root 'tools\bin\weasyprint.exe'
    $versionResult = Invoke-CapturedProcess -FilePath $launcherPath -Arguments @('--version')
    if ($versionResult.ExitCode -ne 0 -or $versionResult.Output -notmatch ('(?i)\b' + [Regex]::Escape($ExpectedVersion) + '\b')) {
        throw "Packaged WeasyPrint did not report expected version $ExpectedVersion. Output: $($versionResult.Output)"
    }

    $conversion = Invoke-CapturedProcess -FilePath $launcherPath -Arguments @('-e', 'utf-8', '-v', '--pdf-forms', $FixtureHtml, $OutputPdf)
    if ($conversion.ExitCode -ne 0) { throw "WeasyPrint HTML-to-PDF gate failed: $($conversion.Output)" }
    Assert-Pdf -Path $OutputPdf -Label 'WeasyPrint direct HTML-to-PDF gate'

    $tempRoot = Join-Path $Root 'data\tmp\weasyprint'
    if (Test-Path -LiteralPath $tempRoot) {
        $leftovers = @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue)
        if ($leftovers.Count -gt 0) {
            $leftovers | Select-Object FullName, Length, LastWriteTime | Format-Table -AutoSize
            throw 'WeasyPrint portable shim left per-invocation extraction/temp state behind.'
        }
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$weasyRoot = Join-Path $portable 'tools\weasyprint'
$backend = Join-Path $weasyRoot 'weasyprint.exe'
$launcher = Join-Path $portable 'tools\bin\weasyprint.exe'
$provenance = Join-Path $weasyRoot 'PROVENANCE.txt'
$checksums = Join-Path $weasyRoot 'SHA256SUMS.txt'
$versionFile = Join-Path $weasyRoot 'VERSION.txt'
$launcherProvenance = Join-Path $portable 'tools\bin\WEASYPRINT_PROVENANCE.txt'

foreach ($required in @($backend, $launcher, $provenance, $checksums, $versionFile, $launcherProvenance)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required packaged WeasyPrint file is missing: $required" }
}
if ((Get-Content -LiteralPath $versionFile -Raw).Trim() -ne $Version) { throw "WeasyPrint VERSION.txt does not report $Version." }
$metadata = Get-KeyValueMetadata -Path $provenance
if ($metadata.VERSION -ne $Version) { throw "WeasyPrint provenance version mismatch: $($metadata.VERSION)" }
if ($metadata.ARCHIVE_SHA256.ToLowerInvariant() -ne $ExpectedArchiveSha256.ToLowerInvariant()) { throw 'WeasyPrint provenance archive hash mismatch.' }

if ((Get-PeMachine -Path $backend) -ne 0x8664) { throw 'Official packaged WeasyPrint executable is not AMD64.' }
if ((Get-PeMachine -Path $launcher) -ne 0x8664) { throw 'PDF_Tunner WeasyPrint launcher is not AMD64.' }
$checksumText = Get-Content -LiteralPath $checksums -Raw
foreach ($entry in @(
    [pscustomobject]@{ Path = $backend; Relative = 'weasyprint.exe' },
    [pscustomobject]@{ Path = $launcher; Relative = '../bin/weasyprint.exe' }
)) {
    $match = [Regex]::Match($checksumText, ('(?im)^([0-9a-f]{64})\s+' + [Regex]::Escape($entry.Relative) + '\s*$'))
    if (-not $match.Success) { throw "WeasyPrint SHA256SUMS.txt does not contain $($entry.Relative)." }
    $actual = (Get-FileHash -LiteralPath $entry.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $match.Groups[1].Value.ToLowerInvariant()) { throw "Packaged WeasyPrint SHA-256 mismatch for $($entry.Relative)." }
}

$originalPath = $env:PATH
try {
    $env:PATH = @((Join-Path $portable 'tools\bin'), (Join-Path $env:SystemRoot 'System32'), $env:SystemRoot) -join ';'
    $resolved = @(& where.exe weasyprint 2>$null)
    if ($LASTEXITCODE -ne 0 -or $resolved.Count -ne 1) { throw 'Isolated PATH did not resolve exactly one weasyprint.' }
    $actualPath = [System.IO.Path]::GetFullPath([string]$resolved[0]).TrimEnd('\')
    $expectedPath = [System.IO.Path]::GetFullPath($launcher).TrimEnd('\')
    if (-not $actualPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Isolated PATH resolved weasyprint outside the portable tree: $actualPath"
    }
}
finally {
    $env:PATH = $originalPath
}

$validationRoot = Join-Path $portable 'data\validation\weasyprint'
$fixtureHtml = Join-Path $validationRoot 'weasyprint-smoke.html'
$directPdf = Join-Path $validationRoot 'direct.pdf'
try {
    New-Item -ItemType Directory -Force -Path $validationRoot | Out-Null
    Set-Content -LiteralPath $fixtureHtml -Encoding utf8 -Value @'
<!doctype html>
<html><head><meta charset="utf-8"><style>body{font-family:sans-serif}h1{color:#222}</style></head>
<body><h1>PDF_Tunner WeasyPrint smoke</h1><p>Portable HTML to PDF validation.</p><form><input name="proof" value="weasyprint-69"></form></body></html>
'@

    Test-WeasyPrintRuntime -Root $portable -ExpectedVersion $Version -FixtureHtml $fixtureHtml -OutputPdf $directPdf

    if ($RequireRelocation) {
        $relocationRoot = Join-Path $env:RUNNER_TEMP ("PDF Tunner WeasyPrint Relocation " + [Guid]::NewGuid().ToString('N'))
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $relocationRoot 'tools\bin'), (Join-Path $relocationRoot 'tools\weasyprint'), (Join-Path $relocationRoot 'data') | Out-Null
            Copy-Item -LiteralPath $launcher -Destination (Join-Path $relocationRoot 'tools\bin\weasyprint.exe') -Force
            Copy-Item -LiteralPath (Join-Path $portable 'tools\bin\WEASYPRINT_PROVENANCE.txt') -Destination (Join-Path $relocationRoot 'tools\bin\WEASYPRINT_PROVENANCE.txt') -Force
            Get-ChildItem -LiteralPath $weasyRoot -Force | Copy-Item -Destination (Join-Path $relocationRoot 'tools\weasyprint') -Recurse -Force
            $relocatedFixture = Join-Path $relocationRoot 'relocated fixture.html'
            $relocatedPdf = Join-Path $relocationRoot 'relocated output.pdf'
            Copy-Item -LiteralPath $fixtureHtml -Destination $relocatedFixture -Force
            Test-WeasyPrintRuntime -Root $relocationRoot -ExpectedVersion $Version -FixtureHtml $relocatedFixture -OutputPdf $relocatedPdf
        }
        finally {
            Remove-Item -LiteralPath $relocationRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($BackendBaseUrl) {
        if (-not $BackendLogRoot) { throw '-BackendBaseUrl requires -BackendLogRoot.' }
        $backendHtmlPdf = Join-Path $validationRoot 'backend-html.pdf'
        Invoke-StirlingMultipart -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/html/pdf') -InputFile $fixtureHtml -MimeType 'text/html' -OutputFile $backendHtmlPdf

        $markdown = Join-Path $validationRoot 'weasyprint-smoke.md'
        Set-Content -LiteralPath $markdown -Encoding utf8 -Value @('# PDF_Tunner WeasyPrint Markdown', '', 'Backend Markdown to PDF validation.')
        $backendMarkdownPdf = Join-Path $validationRoot 'backend-markdown.pdf'
        Invoke-StirlingMultipart -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/markdown/pdf') -InputFile $markdown -MimeType 'text/markdown' -OutputFile $backendMarkdownPdf

        $logs = @(Get-ChildItem -LiteralPath $BackendLogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
        $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
        if ([string]::IsNullOrWhiteSpace($logText)) { throw 'No backend logs were available for WeasyPrint acceptance.' }
        if ($logText -match '(?im)Missing dependency:\s*weasyprint\b') { throw 'Stirling backend reported Missing dependency: weasyprint.' }
        if ($logText -match '(?im)Disabling group:\s*Weasyprint\b') { throw 'Stirling backend disabled the Weasyprint group.' }
        $candidateVersionPattern = [Regex]::Escape($Version) + '(?:\.0)?'
        $minimumVersionPattern = '58\.0(?:\.0)?'
        if ($logText -notmatch ('(?im)\bWeasyPrint\s+' + $candidateVersionPattern + '\s+meets minimum\s+' + $minimumVersionPattern + '\b')) {
            throw "Backend logs did not confirm WeasyPrint $Version (allowing Stirling's patch-normalized version) meets minimum 58.0."
        }
        if ($logText -notmatch '(?im)Running command:\s*weasyprint\b') {
            throw 'Backend logs did not prove a real package-local weasyprint command execution.'
        }
    }

    Write-Host "PASS: official WeasyPrint $Version archive/hash and AMD64 executable validated."
    Write-Host 'PASS: package-local native shim resolves only inside tools/bin and contains PyInstaller temp under data/tmp/weasyprint.'
    Write-Host 'PASS: real WeasyPrint HTML-to-PDF conversion and relocation with spaces validated as requested.'
    if ($BackendBaseUrl) { Write-Host 'PASS: real Stirling HTML-to-PDF and Markdown-to-PDF routes validated through packaged WeasyPrint.' }
}
finally {
    Remove-Item -LiteralPath $validationRoot -Recurse -Force -ErrorAction SilentlyContinue
    $tempRoot = Join-Path $portable 'data\tmp\weasyprint'
    if (Test-Path -LiteralPath $tempRoot) {
        $leftovers = @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue)
        if ($leftovers.Count -eq 0) { Remove-Item -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue }
    }
}
