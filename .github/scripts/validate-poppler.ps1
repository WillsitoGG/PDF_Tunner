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

function New-PopplerFixture {
    param([Parameter(Mandatory = $true)][string]$Path)
    $ascii = [System.Text.Encoding]::ASCII
    $stream = [System.IO.MemoryStream]::new()
    try {
        function Write-Ascii {
            param([Parameter(Mandatory = $true)][string]$Text)
            $bytes = $ascii.GetBytes($Text)
            $stream.Write($bytes, 0, $bytes.Length)
        }

        $offsets = [System.Collections.Generic.List[long]]::new()
        Write-Ascii "%PDF-1.4`n"

        $offsets.Add($stream.Position)
        Write-Ascii "1 0 obj`n<< /Type /Catalog /Pages 2 0 R >>`nendobj`n"
        $offsets.Add($stream.Position)
        Write-Ascii "2 0 obj`n<< /Type /Pages /Kids [3 0 R] /Count 1 >>`nendobj`n"
        $offsets.Add($stream.Position)
        Write-Ascii "3 0 obj`n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> /XObject << /Im1 5 0 R >> >> /Contents 6 0 R >>`nendobj`n"
        $offsets.Add($stream.Position)
        Write-Ascii "4 0 obj`n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>`nendobj`n"

        $imageBytes = [byte[]](255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 0)
        $offsets.Add($stream.Position)
        Write-Ascii "5 0 obj`n<< /Type /XObject /Subtype /Image /Width 2 /Height 2 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length $($imageBytes.Length) >>`nstream`n"
        $stream.Write($imageBytes, 0, $imageBytes.Length)
        Write-Ascii "`nendstream`nendobj`n"

        $content = "BT /F1 18 Tf 72 720 Td (PDF_Tunner Poppler smoke) Tj ET`nq 50 0 0 50 72 640 cm /Im1 Do Q`n"
        $contentBytes = $ascii.GetBytes($content)
        $offsets.Add($stream.Position)
        Write-Ascii "6 0 obj`n<< /Length $($contentBytes.Length) >>`nstream`n"
        $stream.Write($contentBytes, 0, $contentBytes.Length)
        Write-Ascii "endstream`nendobj`n"

        $xrefOffset = $stream.Position
        Write-Ascii "xref`n0 7`n0000000000 65535 f `n"
        foreach ($offset in $offsets) { Write-Ascii (("{0:D10} 00000 n `n" -f $offset)) }
        Write-Ascii "trailer`n<< /Size 7 /Root 1 0 R >>`nstartxref`n$xrefOffset`n%%EOF`n"
        [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-StirlingMultipart {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile
    )
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { throw "Windows curl.exe is unavailable: $curl" }
    $result = Invoke-CapturedProcess -FilePath $curl -Arguments @(
        '--silent', '--show-error', '--fail-with-body', '--connect-timeout', '15', '--max-time', '180',
        '--request', 'POST', '--form', ("fileInput=@{0};type=application/pdf" -f $InputFile),
        '--output', $OutputFile, '--write-out', '%{http_code}', $Uri
    )
    if ($result.ExitCode -ne 0 -or $result.StdOut -ne '200') {
        throw "Stirling API POST failed for $Uri (curl exit $($result.ExitCode), HTTP '$($result.StdOut)'). stderr: $($result.StdErr)"
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$popplerRoot = Join-Path $portable 'tools\poppler'
$binRoot = Join-Path $popplerRoot 'Library\bin'
$provenance = Join-Path $popplerRoot 'PROVENANCE.txt'
$checksums = Join-Path $popplerRoot 'SHA256SUMS.txt'
$versionFile = Join-Path $popplerRoot 'VERSION.txt'
$executables = [ordered]@{
    pdftohtml = Join-Path $binRoot 'pdftohtml.exe'
    pdfinfo = Join-Path $binRoot 'pdfinfo.exe'
    pdfimages = Join-Path $binRoot 'pdfimages.exe'
}

foreach ($required in @($provenance, $checksums, $versionFile) + @($executables.Values)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required packaged Poppler file is missing: $required" }
}

if ((Get-Content -LiteralPath $versionFile -Raw).Trim() -ne $Version) { throw "Poppler VERSION.txt does not report $Version." }
$metadata = Get-KeyValueMetadata -Path $provenance
if ($metadata.VERSION -ne $Version) { throw "Poppler provenance version mismatch: $($metadata.VERSION)" }
if ($metadata.ARCHIVE_SHA256.ToLowerInvariant() -ne $ExpectedArchiveSha256.ToLowerInvariant()) { throw 'Poppler provenance archive hash mismatch.' }

$checksumText = Get-Content -LiteralPath $checksums -Raw
foreach ($entry in $executables.GetEnumerator()) {
    if ((Get-PeMachine -Path $entry.Value) -ne 0x8664) { throw "$($entry.Key).exe is not AMD64." }
    $relative = "Library/bin/$($entry.Key).exe"
    $match = [Regex]::Match($checksumText, ('(?im)^([0-9a-f]{64})\s+' + [Regex]::Escape($relative) + '\s*$'))
    if (-not $match.Success) { throw "Poppler SHA256SUMS.txt does not contain $relative." }
    $actual = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $match.Groups[1].Value.ToLowerInvariant()) { throw "Packaged $($entry.Key).exe SHA-256 mismatch." }

    $reported = Invoke-CapturedProcess -FilePath $entry.Value -Arguments @('-v')
    if ($reported.ExitCode -ne 0 -or $reported.Output -notmatch [Regex]::Escape($Version)) {
        throw "Packaged $($entry.Key) did not report expected version $Version. Output: $($reported.Output)"
    }
}

$originalPath = $env:PATH
try {
    $env:PATH = @($binRoot, (Join-Path $env:SystemRoot 'System32'), $env:SystemRoot) -join ';'
    foreach ($entry in $executables.GetEnumerator()) {
        $resolved = @(& where.exe $entry.Key 2>$null)
        if ($LASTEXITCODE -ne 0 -or $resolved.Count -ne 1) { throw "Isolated PATH did not resolve exactly one $($entry.Key)." }
        $actualPath = [System.IO.Path]::GetFullPath([string]$resolved[0]).TrimEnd('\')
        $expectedPath = [System.IO.Path]::GetFullPath($entry.Value).TrimEnd('\')
        if (-not $actualPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Isolated PATH resolved $($entry.Key) outside the portable tree: $actualPath"
        }
    }
}
finally {
    $env:PATH = $originalPath
}

$validationRoot = Join-Path $portable 'data\validation\poppler'
$fixture = Join-Path $validationRoot 'poppler-smoke.pdf'
try {
    New-Item -ItemType Directory -Force -Path $validationRoot | Out-Null
    New-PopplerFixture -Path $fixture

    $info = Invoke-CapturedProcess -FilePath $executables.pdfinfo -Arguments @($fixture)
    if ($info.ExitCode -ne 0 -or $info.Output -notmatch '(?im)^Pages:\s+1\s*$') { throw "pdfinfo functional gate failed: $($info.Output)" }

    $images = Invoke-CapturedProcess -FilePath $executables.pdfimages -Arguments @('-list', $fixture)
    if ($images.ExitCode -ne 0 -or $images.Output -notmatch '(?im)^\s*1\s+\d+\s+image\s+') { throw "pdfimages functional gate failed: $($images.Output)" }

    foreach ($case in @(
        [pscustomobject]@{ Name = 'html'; Arguments = @('-c', $fixture, 'poppler-html') },
        [pscustomobject]@{ Name = 'markdown'; Arguments = @('-s', '-noframes', '-c', $fixture, 'poppler-markdown') }
    )) {
        $outputDir = Join-Path $validationRoot $case.Name
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
        $conversion = Invoke-CapturedProcess -FilePath $executables.pdftohtml -Arguments $case.Arguments -WorkingDirectory $outputDir
        if ($conversion.ExitCode -ne 0) { throw "pdftohtml $($case.Name) gate failed: $($conversion.Output)" }
        $htmlFiles = @(Get-ChildItem -LiteralPath $outputDir -Recurse -File -Filter '*.html')
        if ($htmlFiles.Count -eq 0) { throw "pdftohtml $($case.Name) gate produced no HTML." }
        $htmlText = ($htmlFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop }) -join "`n"
        if ($htmlText -notmatch 'PDF_Tunner Poppler smoke') { throw "pdftohtml $($case.Name) output did not preserve fixture text." }
    }

    if ($RequireRelocation) {
        $relocationRoot = Join-Path $env:RUNNER_TEMP ("PDF Tunner Poppler Relocation " + [Guid]::NewGuid().ToString('N'))
        $relocatedPoppler = Join-Path $relocationRoot 'tools\poppler'
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $relocatedPoppler) | Out-Null
            Copy-Item -LiteralPath $popplerRoot -Destination $relocatedPoppler -Recurse -Force
            $relocatedBin = Join-Path $relocatedPoppler 'Library\bin'
            $relocatedInfo = Invoke-CapturedProcess -FilePath (Join-Path $relocatedBin 'pdfinfo.exe') -Arguments @($fixture)
            if ($relocatedInfo.ExitCode -ne 0 -or $relocatedInfo.Output -notmatch '(?im)^Pages:\s+1\s*$') { throw 'Relocated pdfinfo failed.' }
            $relocatedHtml = Invoke-CapturedProcess -FilePath (Join-Path $relocatedBin 'pdftohtml.exe') -Arguments @('-s', '-noframes', '-c', $fixture, 'relocated') -WorkingDirectory $relocationRoot
            if ($relocatedHtml.ExitCode -ne 0) { throw "Relocated pdftohtml failed: $($relocatedHtml.Output)" }
        }
        finally {
            Remove-Item -LiteralPath $relocationRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($BackendBaseUrl) {
        if (-not $BackendLogRoot) { throw '-BackendBaseUrl requires -BackendLogRoot.' }
        $backendZip = Join-Path $validationRoot 'backend-pdf-to-html.zip'
        $backendExtract = Join-Path $validationRoot 'backend-html'
        Invoke-StirlingMultipart -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/pdf/html') -InputFile $fixture -OutputFile $backendZip
        $signature = [System.IO.File]::ReadAllBytes($backendZip)
        if ($signature.Length -lt 4 -or $signature[0] -ne 0x50 -or $signature[1] -ne 0x4b) { throw 'Real Stirling PDF-to-HTML route did not return a ZIP.' }
        Expand-Archive -LiteralPath $backendZip -DestinationPath $backendExtract -Force
        $backendHtml = @(Get-ChildItem -LiteralPath $backendExtract -Recurse -File -Filter '*.html')
        if ($backendHtml.Count -eq 0) { throw 'Real Stirling PDF-to-HTML route returned no HTML.' }
        $backendHtmlText = ($backendHtml | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop }) -join "`n"
        if ($backendHtmlText -notmatch 'PDF_Tunner Poppler smoke') { throw 'Real Stirling PDF-to-HTML route did not preserve fixture text.' }

        $logs = @(Get-ChildItem -LiteralPath $BackendLogRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue)
        $logText = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue }) -join "`n"
        if ([string]::IsNullOrWhiteSpace($logText)) { throw 'No backend logs were available for Poppler acceptance.' }
        foreach ($forbidden in @('(?im)Missing dependency:\s*pdftohtml\b', '(?im)Disabling group:\s*Pdftohtml\b')) {
            if ($logText -match $forbidden) { throw "Stirling backend rejected package-local Poppler: $forbidden" }
        }
        if ($logText -notmatch '(?im)Running command:\s+pdftohtml(?:\.exe)?\b') { throw 'Real Stirling PDF-to-HTML route did not log a pdftohtml command.' }
    }
}
finally {
    Remove-Item -LiteralPath $validationRoot -Recurse -Force -ErrorAction SilentlyContinue
    $validationParent = Split-Path -Parent $validationRoot
    if ((Test-Path -LiteralPath $validationParent -PathType Container) -and @(Get-ChildItem -LiteralPath $validationParent -Force -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item -LiteralPath $validationParent -Force -ErrorAction SilentlyContinue
    }
}

$archives = @(Get-ChildItem -LiteralPath $popplerRoot -Recurse -Force -File -Filter '*.zip' -ErrorAction SilentlyContinue)
if ($archives.Count -gt 0) { throw 'Downloaded Poppler archive is present in the final tool directory.' }

Write-Host "PASS: Poppler $Version is package-local, hash-verified, AMD64, functionally tested and independent of runner-installed Poppler."
