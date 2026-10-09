[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BackendBaseUrl,
    [Parameter(Mandatory = $true)][string]$FixturePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdoutTask.GetAwaiter().GetResult().Trim()
        StdErr = $stderrTask.GetAwaiter().GetResult().Trim()
    }
}

function Invoke-StirlingMultipart {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [hashtable]$Fields = @{}
    )

    $systemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot')
    if ([string]::IsNullOrWhiteSpace($systemRoot)) { throw 'SystemRoot is unavailable for backend conversion validation.' }
    $curl = Join-Path $systemRoot 'System32\curl.exe'
    if (-not (Test-Path -LiteralPath $curl -PathType Leaf)) { throw "Windows curl.exe is unavailable: $curl" }

    $headers = "$OutputFile.headers"
    Remove-Item -LiteralPath $headers -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue

    $arguments = @(
        '--silent', '--show-error', '--fail-with-body',
        '--connect-timeout', '15', '--max-time', '180',
        '--request', 'POST',
        '--form', ("fileInput=@{0};type=application/pdf" -f $InputFile)
    )
    foreach ($key in @($Fields.Keys | Sort-Object)) {
        $arguments += @('--form', ("{0}={1}" -f $key, [string]$Fields[$key]))
    }
    $arguments += @('--output', $OutputFile, '--dump-header', $headers, '--write-out', '%{http_code}', $Uri)

    $result = Invoke-CapturedProcess -FilePath $curl -Arguments $arguments
    $headerText = if (Test-Path -LiteralPath $headers -PathType Leaf) { Get-Content -LiteralPath $headers -Raw -ErrorAction SilentlyContinue } else { '' }
    if ($result.ExitCode -ne 0 -or $result.StdOut -ne '200') {
        throw "Stirling API POST failed for $Uri (curl exit $($result.ExitCode), HTTP '$($result.StdOut)'). curl stderr: $($result.StdErr). Response headers: $headerText"
    }
    Remove-Item -LiteralPath $headers -Force -ErrorAction SilentlyContinue
}

function Assert-ZipSignature {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label output is missing: $Path" }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 4 -or $bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4b) {
        throw "$Label output is not a ZIP/OOXML payload: $Path"
    }
}

$fixture = (Resolve-Path -LiteralPath $FixturePath).Path
$backend = $BackendBaseUrl.TrimEnd('/')
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("pdf-tunner-table-e2e-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $work | Out-Null

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $csvZip = Join-Path $work 'tables-csv.zip'
    Invoke-StirlingMultipart -Uri "$backend/api/v1/convert/pdf/csv" -InputFile $fixture -OutputFile $csvZip -Fields @{
        outputFormat = 'csv'
        pageNumbers = 'all'
    }
    if ((Get-Item -LiteralPath $csvZip).Length -le 200) { throw 'PDF-to-CSV response is unexpectedly small.' }
    Assert-ZipSignature -Path $csvZip -Label 'PDF-to-CSV'
    $csvArchive = [System.IO.Compression.ZipFile]::OpenRead($csvZip)
    try {
        $csvEntries = @($csvArchive.Entries | Where-Object { $_.FullName -match '(?i)\.csv$' })
        if ($csvEntries.Count -ne 3) { throw "Expected exactly 3 CSV files from the pinned Stirling tables fixture, got $($csvEntries.Count)." }
        foreach ($entry in $csvEntries) {
            if ($entry.Length -le 0) { throw "CSV entry is empty: $($entry.FullName)" }
            $reader = [System.IO.StreamReader]::new($entry.Open())
            try {
                $text = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
            if ([string]::IsNullOrWhiteSpace($text) -or $text -notmatch ',') {
                throw "CSV entry does not contain tabular CSV content: $($entry.FullName)"
            }
        }
    }
    finally {
        $csvArchive.Dispose()
    }

    $xlsx = Join-Path $work 'tables.xlsx'
    Invoke-StirlingMultipart -Uri "$backend/api/v1/convert/pdf/xlsx" -InputFile $fixture -OutputFile $xlsx
    if ((Get-Item -LiteralPath $xlsx).Length -le 1000) { throw 'PDF-to-XLSX response is unexpectedly small.' }
    Assert-ZipSignature -Path $xlsx -Label 'PDF-to-XLSX'
    $xlsxArchive = [System.IO.Compression.ZipFile]::OpenRead($xlsx)
    try {
        $workbook = $xlsxArchive.GetEntry('xl/workbook.xml')
        if ($null -eq $workbook -or $workbook.Length -le 24) { throw 'XLSX has no coherent xl/workbook.xml.' }
        $worksheets = @($xlsxArchive.Entries | Where-Object { $_.FullName -match '^xl/worksheets/sheet\d+\.xml$' })
        if ($worksheets.Count -eq 0) { throw 'XLSX has no worksheet XML payload.' }
        $reader = [System.IO.StreamReader]::new($workbook.Open())
        try {
            $workbookText = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
        if ($workbookText -notmatch '<sheet') { throw 'XLSX workbook.xml contains no sheet declarations.' }
    }
    finally {
        $xlsxArchive.Dispose()
    }

    Write-Host 'PASS: real Stirling PDF-to-CSV returned exactly three non-empty CSV files from the pinned tables fixture.'
    Write-Host 'PASS: real Stirling PDF-to-XLSX returned a coherent OOXML workbook with worksheet payload.'
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
