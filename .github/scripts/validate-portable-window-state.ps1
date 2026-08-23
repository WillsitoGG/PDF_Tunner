param(
    [Parameter(Mandatory = $true)]
    [string]$PortableRoot,

    [int]$Tolerance = 16
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PortableRoot = (Resolve-Path -LiteralPath $PortableRoot).Path
$Exe = Join-Path $PortableRoot 'PDF_Tunner.exe'
$Marker = Join-Path $PortableRoot 'PDF_TUNNER_PORTABLE'
$StateFile = Join-Path $PortableRoot 'data\tauri\window-state\.window-state.json'
$PortableTauriState = @(
    [PSCustomObject]@{ Name = 'HTTP cookie jar'; Path = (Join-Path $PortableRoot 'data\tauri\http\.cookies') },
    [PSCustomObject]@{ Name = 'Tauri log'; Path = (Join-Path $PortableRoot 'data\tauri\logs\PDF_Tunner.log') },
    [PSCustomObject]@{ Name = 'connection store'; Path = (Join-Path $PortableRoot 'data\tauri\store\connection.json') }
)
$HostTauriRoots = @(
    [PSCustomObject]@{ Name = 'LocalAppData'; Path = (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner') },
    [PSCustomObject]@{ Name = 'Roaming AppData'; Path = (Join-Path $env:APPDATA 'com.willsitogg.pdf-tunner') }
)

if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
    throw "Portable executable missing: $Exe"
}
if (-not (Test-Path -LiteralPath $Marker -PathType Leaf)) {
    throw "Portable marker missing: $Marker"
}
if ($PortableRoot.StartsWith('\\')) {
    throw "Fixed/portable runtime validation must not execute from UNC: $PortableRoot"
}

# The job is ephemeral. Start from known-zero Local + Roaming AppData baselines.
# This cleanup happens BEFORE either validation launch; no host state is deleted
# after launch, so a green result proves PDF_Tunner did not persist new content.
foreach ($root in $HostTauriRoots) {
    Remove-Item -LiteralPath $root.Path -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $root.Path) {
        throw "Could not establish clean host $($root.Name) Tauri baseline: $($root.Path)"
    }
    Write-Host "Clean host $($root.Name) baseline: $($root.Path)"
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class PdfTunnerWindowProbe
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    public static IntPtr FindVisibleTopLevelWindow(int processId)
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
        {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid == (uint)processId && IsWindowVisible(hWnd))
            {
                found = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@

function Wait-ForWindow {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 150
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $Process.Refresh()
        if ($Process.HasExited) {
            throw "PDF_Tunner exited before exposing a top-level window (exit code $($Process.ExitCode))."
        }

        $hwnd = [PdfTunnerWindowProbe]::FindVisibleTopLevelWindow($Process.Id)
        if ($hwnd -ne [IntPtr]::Zero) {
            return $hwnd
        }
        Start-Sleep -Milliseconds 500
    }

    throw "Timed out waiting for PDF_Tunner top-level window (PID $($Process.Id))."
}

function Get-Geometry {
    param([Parameter(Mandatory = $true)][IntPtr]$Hwnd)

    $outer = New-Object PdfTunnerWindowProbe+RECT
    $client = New-Object PdfTunnerWindowProbe+RECT
    if (-not [PdfTunnerWindowProbe]::GetWindowRect($Hwnd, [ref]$outer)) {
        throw 'GetWindowRect failed.'
    }
    if (-not [PdfTunnerWindowProbe]::GetClientRect($Hwnd, [ref]$client)) {
        throw 'GetClientRect failed.'
    }

    [PSCustomObject]@{
        X = $outer.Left
        Y = $outer.Top
        OuterWidth = $outer.Right - $outer.Left
        OuterHeight = $outer.Bottom - $outer.Top
        ClientWidth = $client.Right - $client.Left
        ClientHeight = $client.Bottom - $client.Top
    }
}

function Assert-Near {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Expected,
        [Parameter(Mandatory = $true)][int]$Actual,
        [Parameter(Mandatory = $true)][int]$AllowedDelta
    )

    $delta = [Math]::Abs($Expected - $Actual)
    if ($delta -gt $AllowedDelta) {
        throw "$Name mismatch: expected $Expected, actual $Actual, delta $delta > tolerance $AllowedDelta."
    }
}

function Stop-PortableNormally {
    param([Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process)

    $Process.Refresh()
    if (-not $Process.HasExited) {
        $closed = $Process.CloseMainWindow()
        Write-Host "CloseMainWindow(PID=$($Process.Id)) => $closed"
        if (-not $closed) {
            throw "Could not request normal window close for PID $($Process.Id)."
        }
        if (-not $Process.WaitForExit(20000)) {
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            throw "PDF_Tunner PID $($Process.Id) did not exit within 20 seconds."
        }
    }

    Start-Sleep -Seconds 2
    $escapedRoot = [Regex]::Escape($PortableRoot)
    $leftovers = @(Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and $_.CommandLine -match $escapedRoot
    })
    if ($leftovers.Count -gt 0) {
        $leftovers | Select-Object ProcessId, Name, CommandLine | Format-List
        throw 'Portable child processes remained after normal shutdown.'
    }
}

function Assert-NoHostTauriState {
    foreach ($root in $HostTauriRoots) {
        if (-not (Test-Path -LiteralPath $root.Path -PathType Container)) {
            Write-Host "Host $($root.Name) identifier root was not created: $($root.Path)"
            continue
        }

        $items = @(Get-ChildItem -LiteralPath $root.Path -Recurse -Force -ErrorAction SilentlyContinue)
        if ($items.Count -gt 0) {
            Write-Host "Unexpected host $($root.Name) Tauri content:"
            $items |
                Select-Object FullName, PSIsContainer, Length, LastWriteTime |
                Format-Table -AutoSize
            throw "Portable PDF_Tunner leaked content into host $($root.Name): $($root.Path)"
        }

        # Native/Tauri path resolution may materialize the identifier directory
        # itself. An empty root is not persisted application state.
        Write-Host "Host $($root.Name) identifier directory exists but is empty: $($root.Path)"
    }
}

function Wait-ForPortableTauriState {
    param([int]$TimeoutSeconds = 30)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $missing = @($PortableTauriState | Where-Object {
            -not (Test-Path -LiteralPath $_.Path -PathType Leaf)
        })
        if ($missing.Count -eq 0) {
            foreach ($item in $PortableTauriState) {
                $file = Get-Item -LiteralPath $item.Path
                Write-Host "Package-local $($item.Name): $($item.Path) ($($file.Length) bytes)"
            }
            return
        }
        Start-Sleep -Milliseconds 500
    }

    $PortableTauriState | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Path = $_.Path
            Exists = Test-Path -LiteralPath $_.Path -PathType Leaf
        }
    } | Format-Table -AutoSize
    throw 'Expected package-local Tauri state was not fully created.'
}

# Use a position/size comfortably inside the standard GitHub Windows runner
# desktop while being intentionally different from Stirling defaults.
$targetX = 111
$targetY = 87
$targetOuterWidth = 840
$targetOuterHeight = 620
$SW_RESTORE = 9
$SWP_NOZORDER = 0x0004
$SWP_NOACTIVATE = 0x0010
$SWP_SHOWWINDOW = 0x0040
$flags = $SWP_NOZORDER -bor $SWP_NOACTIVATE -bor $SWP_SHOWWINDOW

Write-Host '=== First packaged launch: establish and persist deliberate geometry ==='
$first = Start-Process -FilePath $Exe -WorkingDirectory $PortableRoot -PassThru
try {
    $firstHwnd = Wait-ForWindow -Process $first
    [void][PdfTunnerWindowProbe]::ShowWindow($firstHwnd, $SW_RESTORE)
    if (-not [PdfTunnerWindowProbe]::SetWindowPos(
        $firstHwnd,
        [IntPtr]::Zero,
        $targetX,
        $targetY,
        $targetOuterWidth,
        $targetOuterHeight,
        $flags)) {
        throw 'SetWindowPos failed on first launch.'
    }

    Start-Sleep -Seconds 3
    $firstGeometry = Get-Geometry -Hwnd $firstHwnd
    $firstGeometry | Format-List

    Assert-Near -Name 'first launch X' -Expected $targetX -Actual $firstGeometry.X -AllowedDelta $Tolerance
    Assert-Near -Name 'first launch Y' -Expected $targetY -Actual $firstGeometry.Y -AllowedDelta $Tolerance

    Wait-ForPortableTauriState
    Assert-NoHostTauriState
    Stop-PortableNormally -Process $first
} finally {
    if (-not $first.HasExited) {
        Stop-Process -Id $first.Id -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $StateFile -PathType Leaf)) {
    throw "Portable window-state file was not written: $StateFile"
}
Assert-NoHostTauriState

$stateRoot = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
$stateProperties = @($stateRoot.PSObject.Properties)
if ($stateProperties.Count -eq 0) {
    throw "Portable window-state JSON contains no windows: $StateFile"
}

$mainProperty = $stateRoot.PSObject.Properties['main']
if ($null -eq $mainProperty) {
    $mainProperty = $stateProperties | Select-Object -First 1
    Write-Host "No 'main' label found; validating first stored label '$($mainProperty.Name)'."
}
$stored = $mainProperty.Value

Write-Host "Stored portable state ($($mainProperty.Name)):"
$stored | Format-List

Assert-Near -Name 'stored X' -Expected $firstGeometry.X -Actual ([int]$stored.x) -AllowedDelta $Tolerance
Assert-Near -Name 'stored Y' -Expected $firstGeometry.Y -Actual ([int]$stored.y) -AllowedDelta $Tolerance
Assert-Near -Name 'stored client width' -Expected $firstGeometry.ClientWidth -Actual ([int]$stored.width) -AllowedDelta $Tolerance
Assert-Near -Name 'stored client height' -Expected $firstGeometry.ClientHeight -Actual ([int]$stored.height) -AllowedDelta $Tolerance
if ([bool]$stored.maximized) { throw 'Deliberate normal window was persisted as maximized.' }
if ([bool]$stored.fullscreen) { throw 'Deliberate normal window was persisted as fullscreen.' }

Write-Host '=== Second packaged launch: prove geometry restoration ==='
$second = Start-Process -FilePath $Exe -WorkingDirectory $PortableRoot -PassThru
try {
    $secondHwnd = Wait-ForWindow -Process $second
    $deadline = (Get-Date).AddSeconds(30)
    $restored = $null
    while ((Get-Date) -lt $deadline) {
        $candidate = Get-Geometry -Hwnd $secondHwnd
        $positionOk = ([Math]::Abs($candidate.X - [int]$stored.x) -le $Tolerance) -and
            ([Math]::Abs($candidate.Y - [int]$stored.y) -le $Tolerance)
        $sizeOk = ([Math]::Abs($candidate.ClientWidth - [int]$stored.width) -le $Tolerance) -and
            ([Math]::Abs($candidate.ClientHeight - [int]$stored.height) -le $Tolerance)
        if ($positionOk -and $sizeOk) {
            $restored = $candidate
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if ($null -eq $restored) {
        $last = Get-Geometry -Hwnd $secondHwnd
        $last | Format-List
        throw 'Second packaged launch did not restore saved portable geometry within tolerance.'
    }

    Write-Host 'Restored second-launch geometry:'
    $restored | Format-List
    Assert-Near -Name 'restored X' -Expected ([int]$stored.x) -Actual $restored.X -AllowedDelta $Tolerance
    Assert-Near -Name 'restored Y' -Expected ([int]$stored.y) -Actual $restored.Y -AllowedDelta $Tolerance
    Assert-Near -Name 'restored client width' -Expected ([int]$stored.width) -Actual $restored.ClientWidth -AllowedDelta $Tolerance
    Assert-Near -Name 'restored client height' -Expected ([int]$stored.height) -Actual $restored.ClientHeight -AllowedDelta $Tolerance

    Assert-NoHostTauriState
    Stop-PortableNormally -Process $second
} finally {
    if (-not $second.HasExited) {
        Stop-Process -Id $second.Id -Force -ErrorAction SilentlyContinue
    }
}

Assert-NoHostTauriState
Write-Host "PASS: portable Tauri state stayed under $PortableRoot\data, window state restored on the second launch, and Local/Roaming AppData contain no PDF_Tunner state."
