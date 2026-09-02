[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [int]$MaxBytes = 2097152,
    [int]$MaxLogTailBytes = 131072,
    [int]$MaxLogFiles = 8
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$diagnostics = [System.IO.Path]::GetFullPath((Join-Path $PWD $OutputRoot))
Remove-Item -LiteralPath $diagnostics -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $diagnostics | Out-Null

function Write-TableSnapshot {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$First = 500
    )
    @($InputObject) |
        Select-Object -First $First |
        Format-Table -AutoSize |
        Out-String -Width 4096 |
        Set-Content -LiteralPath $Path -Encoding utf8
}

function Copy-BoundedLogTail {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][int]$TailBytes
    )

    $file = Get-Item -LiteralPath $Source -ErrorAction Stop
    $length = [int64]$file.Length
    $take = [int][Math]::Min([int64]$TailBytes, $length)
    $bytes = [byte[]]::new($take)
    $bytesRead = 0
    $stream = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        if ($take -gt 0) {
            [void]$stream.Seek(-1 * [int64]$take, [System.IO.SeekOrigin]::End)
            while ($bytesRead -lt $take) {
                $read = $stream.Read($bytes, $bytesRead, $take - $bytesRead)
                if ($read -le 0) { break }
                $bytesRead += $read
            }
        }
    }
    finally {
        $stream.Dispose()
    }

    if ($bytesRead -eq 0) {
        $text = ''
    }
    else {
        if ($bytesRead -lt $bytes.Length) {
            $trimmed = [byte[]]::new($bytesRead)
            [Array]::Copy($bytes, $trimmed, $bytesRead)
            $bytes = $trimmed
        }
        $text = [System.Text.UTF8Encoding]::new($false, $false).GetString($bytes)
    }

    $header = @(
        "SOURCE=$($file.FullName)",
        "ORIGINAL_BYTES=$length",
        "TAIL_BYTES_LIMIT=$TailBytes",
        "TAIL_BYTES_READ=$bytesRead",
        '--- LOG TAIL ---'
    ) -join "`r`n"
    Set-Content -LiteralPath $Destination -Encoding utf8 -Value ($header + "`r`n" + $text)
}

function Get-DiagnosticBytes {
    param([Parameter(Mandatory = $true)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return [int64]0 }
    return [int64](($files | Measure-Object -Property Length -Sum).Sum)
}

$data = Join-Path $portable 'data'
$logRoot = Join-Path $data 'logs'
$hostTempRoot = [System.IO.Path]::GetTempPath()
$protocolKey = 'HKCU:\Software\Classes\pdf-tunner'

@(
    (Join-Path $hostTempRoot 'stirling-pdf'),
    (Join-Path $hostTempRoot 'stirling-mobile-scanner')
) | ForEach-Object {
    [PSCustomObject]@{ Path = $_; Exists = Test-Path -LiteralPath $_ }
} | Format-Table -AutoSize | Out-String -Width 4096 |
    Set-Content -LiteralPath (Join-Path $diagnostics 'host-temp-state.txt') -Encoding utf8

$hostProfilePaths = @(
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner\EBWebView'),
    (Join-Path $env:APPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:APPDATA 'Stirling-PDF')
)
$hostProfilePaths | ForEach-Object {
    [PSCustomObject]@{ Path = $_; Exists = Test-Path -LiteralPath $_ }
} | Format-Table -AutoSize | Out-String -Width 4096 |
    Set-Content -LiteralPath (Join-Path $diagnostics 'host-profile-state.txt') -Encoding utf8

$hostInventory = @()
foreach ($root in @($env:LOCALAPPDATA, $env:APPDATA)) {
    if (Test-Path -LiteralPath $root) {
        $hostInventory += Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)pdf.?tunner|stirling|willsitogg|pdf-tunner' } |
            Select-Object FullName, PSIsContainer, Length, LastWriteTime
    }
}
Write-TableSnapshot -InputObject $hostInventory -Path (Join-Path $diagnostics 'host-app-inventory.txt') -First 200

$hostAppTree = @()
foreach ($root in @(
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:APPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:APPDATA 'Stirling-PDF')
)) {
    if (Test-Path -LiteralPath $root) {
        $hostAppTree += [PSCustomObject]@{ FullName = $root; PSIsContainer = $true; Length = $null; LastWriteTime = (Get-Item -LiteralPath $root).LastWriteTime }
        $hostAppTree += Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue |
            Select-Object FullName, PSIsContainer, Length, LastWriteTime
    }
}
Write-TableSnapshot -InputObject $hostAppTree -Path (Join-Path $diagnostics 'host-app-tree.txt') -First 500

[PSCustomObject]@{ Path = $protocolKey; Exists = Test-Path -LiteralPath $protocolKey } |
    Format-List | Out-String -Width 4096 |
    Set-Content -LiteralPath (Join-Path $diagnostics 'registry-state.txt') -Encoding utf8

Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -match '(?i)PDF_Tunner|java|msedgewebview2|weasyprint' -or
        ($_.CommandLine -and $_.CommandLine -match '(?i)PDF_Tunner|Stirling|webview2|weasyprint')
    } |
    Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine |
    Format-List |
    Out-String -Width 4096 |
    Set-Content -LiteralPath (Join-Path $diagnostics 'processes.txt') -Encoding utf8

if (Test-Path -LiteralPath $data) {
    Get-ChildItem -LiteralPath $data -Recurse -Force -ErrorAction SilentlyContinue |
        Select-Object -First 750 FullName, PSIsContainer, Length, LastWriteTime |
        Format-Table -AutoSize |
        Out-String -Width 4096 |
        Set-Content -LiteralPath (Join-Path $diagnostics 'portable-data-tree.txt') -Encoding utf8
}

$logFiles = @()
if (Test-Path -LiteralPath $logRoot -PathType Container) {
    $logFiles = @(Get-ChildItem -LiteralPath $logRoot -Recurse -Force -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object FullName)
}
$logFiles |
    Select-Object FullName, Length, LastWriteTime |
    Format-Table -AutoSize |
    Out-String -Width 4096 |
    Set-Content -LiteralPath (Join-Path $diagnostics 'backend-log-inventory.txt') -Encoding utf8

$logDiagnostics = Join-Path $diagnostics 'backend-logs'
New-Item -ItemType Directory -Force -Path $logDiagnostics | Out-Null
$selectedLogs = @(
    $logFiles |
        Sort-Object `
            @{ Expression = { if ($_.Name -match '(?i)tauri-backend|info|stirling-pdf|PDF_Tunner') { 0 } else { 1 } }; Ascending = $true }, `
            @{ Expression = { $_.LastWriteTime }; Descending = $true } |
        Select-Object -First $MaxLogFiles
)
$index = 0
foreach ($log in $selectedLogs) {
    $index++
    $safeName = ($log.FullName.Substring($logRoot.Length).TrimStart('\') -replace '[\\/:*?"<>|]', '_')
    $destination = Join-Path $logDiagnostics ('{0:D2}-{1}.tail.txt' -f $index, $safeName)
    Copy-BoundedLogTail -Source $log.FullName -Destination $destination -TailBytes $MaxLogTailBytes
}

$webView = Join-Path $data 'webview2'
if (Test-Path -LiteralPath $webView) {
    $webViewFiles = @(Get-ChildItem -LiteralPath $webView -Recurse -Force -File -ErrorAction SilentlyContinue)
    $webViewBytes = ($webViewFiles | Measure-Object -Property Length -Sum).Sum
    @(
        "Path: $webView",
        "Files: $($webViewFiles.Count)",
        "Bytes: $webViewBytes",
        '',
        'Sample files:'
    ) + @($webViewFiles | Select-Object -First 100 | ForEach-Object { $_.FullName }) |
        Set-Content -LiteralPath (Join-Path $diagnostics 'webview2-state.txt') -Encoding utf8
}

$portableFiles = @(Get-ChildItem -LiteralPath $portable -Recurse -Force -File -ErrorAction SilentlyContinue)
@(
    "PORTABLE_FILE_COUNT=$($portableFiles.Count)",
    "PORTABLE_PAYLOAD_BYTES=$(($portableFiles | Measure-Object -Property Length -Sum).Sum)",
    "BACKEND_LOG_COUNT=$($logFiles.Count)",
    "BACKEND_LOG_TAILS_RETAINED=$($selectedLogs.Count)"
) | Set-Content -LiteralPath (Join-Path $diagnostics 'portable-layout-summary.txt') -Encoding ascii

$diagnosticBytes = Get-DiagnosticBytes -Root $diagnostics
if ($diagnosticBytes -gt $MaxBytes) {
    foreach ($optionalName in @('host-app-tree.txt', 'portable-data-tree.txt', 'webview2-state.txt', 'host-app-inventory.txt')) {
        Remove-Item -LiteralPath (Join-Path $diagnostics $optionalName) -Force -ErrorAction SilentlyContinue
        $diagnosticBytes = Get-DiagnosticBytes -Root $diagnostics
        if ($diagnosticBytes -le $MaxBytes) { break }
    }
}

$diagnosticBytes = Get-DiagnosticBytes -Root $diagnostics
if ($diagnosticBytes -gt $MaxBytes) {
    throw "Bounded startup diagnostics still exceed the $MaxBytes-byte retention cap after optional snapshots were removed: $diagnosticBytes bytes."
}

Write-Host "Startup diagnostics collected: $diagnosticBytes bytes (cap $MaxBytes)."
Write-Host "Retained $($selectedLogs.Count) bounded backend log tail(s) from $($logFiles.Count) discovered package-local log(s)."
