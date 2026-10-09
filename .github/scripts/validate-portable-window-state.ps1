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
    [PSCustomObject]@{ Name = 'Tauri log'; Path = (Join-Path $PortableRoot 'data\logs\tauri\PDF_Tunner.log') },
    [PSCustomObject]@{ Name = 'connection store'; Path = (Join-Path $PortableRoot 'data\tauri\store\connection.json') },
    [PSCustomObject]@{ Name = 'token store'; Path = (Join-Path $PortableRoot 'data\tauri\store\tokens.json') }
)
$HostTauriRoots = @(
    [PSCustomObject]@{ Name = 'LocalAppData'; Path = (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner') },
    [PSCustomObject]@{ Name = 'Roaming AppData'; Path = (Join-Path $env:APPDATA 'com.willsitogg.pdf-tunner') }
)
$ProtocolKey = 'HKCU:\Software\Classes\pdf-tunner'
$ProtocolExistedBefore = Test-Path -LiteralPath $ProtocolKey

if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
    throw "Portable executable missing: $Exe"
}
if (-not (Test-Path -LiteralPath $Marker -PathType Leaf)) {
    throw "Portable marker missing: $Marker"
}
if ($PortableRoot.StartsWith('\\')) {
    throw "Portable validation must not execute from UNC: $PortableRoot"
}

# Establish a known-zero host baseline before either launch. Nothing below
# deletes host AppData after launch, so a green result cannot be manufactured
# by post-launch cleanup.
foreach ($root in $HostTauriRoots) {
    Remove-Item -LiteralPath $root.Path -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $root.Path) {
        throw "Could not establish clean host $($root.Name) baseline: $($root.Path)"
    }
    Write-Host "Clean host $($root.Name) baseline: $($root.Path)"
}

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

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

    [DllImport("user32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, EntryPoint = "GetWindowTextW")]
    private static extern int GetWindowTextNative(IntPtr hWnd, StringBuilder text, int maxCount);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, ExactSpelling = true, EntryPoint = "GetClassNameW")]
    private static extern int GetClassNameNative(IntPtr hWnd, StringBuilder className, int maxCount);

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

    public static string GetWindowTitle(IntPtr hWnd)
    {
        StringBuilder text = new StringBuilder(512);
        GetWindowTextNative(hWnd, text, text.Capacity);
        return text.ToString();
    }

    public static string GetWindowClass(IntPtr hWnd)
    {
        StringBuilder className = new StringBuilder(256);
        GetClassNameNative(hWnd, className, className.Capacity);
        return className.ToString();
    }

    public static IntPtr[] GetVisibleTopLevelWindows(int processId)
    {
        List<IntPtr> found = new List<IntPtr>();
        EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
        {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid == (uint)processId && IsWindowVisible(hWnd))
            {
                found.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }

    public static IntPtr FindVisibleTopLevelWindow(int processId, string expectedTitle)
    {
        foreach (IntPtr hWnd in GetVisibleTopLevelWindows(processId))
        {
            if (String.Equals(GetWindowTitle(hWnd), expectedTitle, StringComparison.OrdinalIgnoreCase))
            {
                return hWnd;
            }
        }
        return IntPtr.Zero;
    }
}
'@

$SW_RESTORE = 9
$SWP_NOZORDER = 0x0004
$SWP_NOACTIVATE = 0x0010
$SWP_SHOWWINDOW = 0x0040
$SetWindowFlags = $SWP_NOZORDER -bor $SWP_NOACTIVATE -bor $SWP_SHOWWINDOW

function Wait-ForWindow {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 150
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $Process.Refresh()
        if ($Process.HasExited) {
            throw "PDF_Tunner exited before exposing a top-level window (exit code $($Process.ExitCode))."
        }
        # Tauri's configured product window title is PDF_Tunner. Ignore visible
        # helper/popup windows owned by the same PID; only the actual main window
        # can satisfy the persistence gate.
        $hwnd = [PdfTunnerWindowProbe]::FindVisibleTopLevelWindow($Process.Id, 'PDF_Tunner')
        if ($hwnd -ne [IntPtr]::Zero) {
            return $hwnd
        }
        Start-Sleep -Milliseconds 500
    }
    Write-Host "Visible top-level windows owned by PID $($Process.Id) while waiting for the 'PDF_Tunner' main window:"
    Get-VisibleWindowDiagnostics -ProcessId $Process.Id | Format-List
    throw "Timed out waiting for the 'PDF_Tunner' main window (PID $($Process.Id))."
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

function Get-VisibleWindowDiagnostics {
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    foreach ($hwnd in [PdfTunnerWindowProbe]::GetVisibleTopLevelWindows($ProcessId)) {
        $geometry = Get-Geometry -Hwnd $hwnd
        [PSCustomObject]@{
            Handle = ('0x{0:X}' -f $hwnd.ToInt64())
            Title = [PdfTunnerWindowProbe]::GetWindowTitle($hwnd)
            Class = [PdfTunnerWindowProbe]::GetWindowClass($hwnd)
            X = $geometry.X
            Y = $geometry.Y
            OuterWidth = $geometry.OuterWidth
            OuterHeight = $geometry.OuterHeight
            ClientWidth = $geometry.ClientWidth
            ClientHeight = $geometry.ClientHeight
        }
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

function Assert-NoHostState {
    foreach ($root in $HostTauriRoots) {
        if (-not (Test-Path -LiteralPath $root.Path -PathType Container)) {
            Write-Host "Host $($root.Name) identifier root was not created: $($root.Path)"
            continue
        }

        $items = @(Get-ChildItem -LiteralPath $root.Path -Recurse -Force -ErrorAction SilentlyContinue)
        if ($items.Count -gt 0) {
            Write-Host "Unexpected host $($root.Name) content:"
            $items | Select-Object FullName, PSIsContainer, Length, LastWriteTime | Format-Table -AutoSize
            throw "Portable PDF_Tunner leaked content into host $($root.Name): $($root.Path)"
        }
        Write-Host "Host $($root.Name) identifier directory exists but is empty: $($root.Path)"
    }

    if (-not $ProtocolExistedBefore -and (Test-Path -LiteralPath $ProtocolKey)) {
        throw "Portable launch created protocol registration in host registry: $ProtocolKey"
    }
}

function Wait-ForPortableState {
    param([int]$TimeoutSeconds = 30)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $missing = @($PortableTauriState | Where-Object { -not (Test-Path -LiteralPath $_.Path -PathType Leaf) })
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

function Set-GeometryAndWait {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Hwnd,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$OuterWidth,
        [Parameter(Mandatory = $true)][int]$OuterHeight,
        [int]$TimeoutSeconds = 30
    )

    # Run #55 proved the native window can become visible before Tauri/WebView
    # has finished its startup geometry pass. Re-apply the deliberate geometry
    # until it survives that race. Saved-state and second-launch checks remain strict.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $last = $null
    while ((Get-Date) -lt $deadline) {
        [void][PdfTunnerWindowProbe]::ShowWindow($Hwnd, $SW_RESTORE)
        if (-not [PdfTunnerWindowProbe]::SetWindowPos(
            $Hwnd,
            [IntPtr]::Zero,
            $X,
            $Y,
            $OuterWidth,
            $OuterHeight,
            $SetWindowFlags)) {
            throw 'SetWindowPos failed while establishing first-launch geometry.'
        }

        Start-Sleep -Milliseconds 750
        $last = Get-Geometry -Hwnd $Hwnd
        $positionOk = ([Math]::Abs($last.X - $X) -le $Tolerance) -and
            ([Math]::Abs($last.Y - $Y) -le $Tolerance)
        $sizeOk = ([Math]::Abs($last.OuterWidth - $OuterWidth) -le $Tolerance) -and
            ([Math]::Abs($last.OuterHeight - $OuterHeight) -le $Tolerance)
        if ($positionOk -and $sizeOk) {
            return $last
        }
    }

    if ($null -ne $last) {
        Write-Host 'Last first-launch geometry:'
        $last | Format-List
    }
    throw 'First packaged launch did not retain deliberate normal geometry within the startup window.'
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

$targetX = 111
$targetY = 87
$targetOuterWidth = 840
$targetOuterHeight = 620

Write-Host '=== First packaged launch: establish and persist deliberate geometry ==='
$first = Start-Process -FilePath $Exe -WorkingDirectory $PortableRoot -PassThru
try {
    $firstHwnd = Wait-ForWindow -Process $first
    $firstGeometry = Set-GeometryAndWait `
        -Hwnd $firstHwnd `
        -X $targetX `
        -Y $targetY `
        -OuterWidth $targetOuterWidth `
        -OuterHeight $targetOuterHeight

    Write-Host 'Established first-launch geometry:'
    $firstGeometry | Format-List
    Assert-Near -Name 'first launch X' -Expected $targetX -Actual $firstGeometry.X -AllowedDelta $Tolerance
    Assert-Near -Name 'first launch Y' -Expected $targetY -Actual $firstGeometry.Y -AllowedDelta $Tolerance
    Assert-Near -Name 'first launch outer width' -Expected $targetOuterWidth -Actual $firstGeometry.OuterWidth -AllowedDelta $Tolerance
    Assert-Near -Name 'first launch outer height' -Expected $targetOuterHeight -Actual $firstGeometry.OuterHeight -AllowedDelta $Tolerance

    Wait-ForPortableState
    Assert-NoHostState
    Stop-PortableNormally -Process $first
} finally {
    $first.Refresh()
    if (-not $first.HasExited) {
        Stop-Process -Id $first.Id -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path -LiteralPath $StateFile -PathType Leaf)) {
    throw "Portable window-state file was not written: $StateFile"
}
Assert-NoHostState

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
        Write-Host 'Selected PDF_Tunner main-window geometry on second launch:'
        $last | Format-List
        Write-Host "All visible top-level windows owned by second-launch PID $($second.Id):"
        Get-VisibleWindowDiagnostics -ProcessId $second.Id | Format-List
        throw 'Second packaged launch did not restore saved portable geometry within tolerance.'
    }

    Write-Host 'Restored second-launch geometry:'
    $restored | Format-List
    Assert-Near -Name 'restored X' -Expected ([int]$stored.x) -Actual $restored.X -AllowedDelta $Tolerance
    Assert-Near -Name 'restored Y' -Expected ([int]$stored.y) -Actual $restored.Y -AllowedDelta $Tolerance
    Assert-Near -Name 'restored client width' -Expected ([int]$stored.width) -Actual $restored.ClientWidth -AllowedDelta $Tolerance
    Assert-Near -Name 'restored client height' -Expected ([int]$stored.height) -Actual $restored.ClientHeight -AllowedDelta $Tolerance

    Wait-ForPortableState
    Assert-NoHostState
    Stop-PortableNormally -Process $second
} finally {
    $second.Refresh()
    if (-not $second.HasExited) {
        Stop-Process -Id $second.Id -Force -ErrorAction SilentlyContinue
    }
}

Assert-NoHostState
Write-Host "PASS: portable Tauri state remained package-local, window geometry persisted/restored across two packaged launches, host Local/Roaming AppData stayed empty, registry state stayed clean, and portable child processes exited."
