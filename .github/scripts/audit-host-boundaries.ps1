[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$PortableRoot,
    [Parameter(Mandatory=$false)][string]$ReportDirectory,
    [switch]$SelfTest,
    [ValidateRange(5,180)][int]$ObserveSeconds = 40,
    [switch]$FailOnObservedEscape
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$portable = $null
$exe = $null
$reportDir = $null
if (-not $SelfTest) {
    if ([string]::IsNullOrWhiteSpace($PortableRoot) -or [string]::IsNullOrWhiteSpace($ReportDirectory)) {
        throw 'PortableRoot and ReportDirectory are required for the real audit.'
    }
    $portable = (Resolve-Path -LiteralPath $PortableRoot).Path.TrimEnd('\')
    $exe = Join-Path $portable 'PDF_Tunner.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Missing executable $exe" }
    if (-not (Test-Path -LiteralPath (Join-Path $portable 'PDF_TUNNER_PORTABLE') -PathType Leaf)) { throw 'Portable marker missing' }
    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) { throw 'TCP audit unavailable' }
    New-Item -Path $ReportDirectory -ItemType Directory -Force | Out-Null
    $reportDir = (Resolve-Path -LiteralPath $ReportDirectory).Path
}
$hostPaths=@(
    (Join-Path $env:APPDATA 'Stirling-PDF'),
    (Join-Path $env:APPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:LOCALAPPDATA 'com.willsitogg.pdf-tunner'),
    (Join-Path $env:LOCALAPPDATA 'Stirling-PDF'),
    (Join-Path $env:LOCALAPPDATA 'PDF_Tunner'),
    (Join-Path $env:TEMP 'stirling-pdf'),
    (Join-Path $env:TEMP 'stirling-mobile-scanner'),
    # ProcMon on Windows 10 showed HotSpot perfdata and the Windows App
    # Installer python3 alias writing outside the portable folder.
    (Join-Path $env:TEMP ('hsperfdata_' + $env:USERNAME)),
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir'),
    (Join-Path $env:USERPROFILE '.stirling-pdf'),
    (Join-Path $env:ProgramData 'Stirling-PDF')
)
$regKeys=@(
    'HKCU:\Software\Stirling-PDF',
    'HKCU:\Software\PDF_Tunner',
    'HKCU:\Software\com.willsitogg.pdf-tunner',
    'HKCU:\Software\Classes\pdf-tunner',
    'HKCU:\Software\Classes\Applications\PDF_Tunner.exe',
    'HKCU:\Software\Classes\.pdf',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf'
)
function HostFiles {
    $snap=@{}
    foreach($p in $hostPaths){
        if(-not (Test-Path -LiteralPath $p)){continue}
        $found=@(Get-Item -LiteralPath $p -Force)
        $found+=@(Get-ChildItem -LiteralPath $p -File -Force -Recurse -ErrorAction SilentlyContinue)
        foreach($x in $found){
            if($null -eq $x){continue}
            # DirectoryInfo has no Length member under StrictMode. Treat a
            # directory as a sentinel, recording its last-write time separately.
            $size = if($x -is [System.IO.FileInfo]) { [string]$x.Length } else { '<DIR>' }
            $snap[$x.FullName] = "$size|$($x.LastWriteTimeUtc.Ticks)"
        }
    }
    return $snap
}
function RegistryState {
    $snap=@{}
    foreach($p in $regKeys){
        if(-not (Test-Path -LiteralPath $p)){$snap[$p]='[absent]';continue}
        $items=@($p)
        $items+=@(Get-ChildItem -LiteralPath $p -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.PSPath })
        $lines=[System.Collections.Generic.List[string]]::new()
        foreach($item in $items){
            try{
                $value=Get-ItemProperty -LiteralPath $item -ErrorAction Stop
                $pairs=@($value.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$' } | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" })
                $lines.Add("$item=$($pairs -join ';')")
            }catch{$lines.Add("$item=[unreadable]")}
        }
        $snap[$p]=(@($lines | Sort-Object) -join '|')
    }
    return $snap
}
function Changes([hashtable]$before,[hashtable]$after){
    $result=[System.Collections.Generic.List[object]]::new()
    foreach($key in @( @($before.Keys) + @($after.Keys) | Select-Object -Unique)){
        $b=if($before.ContainsKey($key)){$before[$key]}else{'[absent]'}
        $a=if($after.ContainsKey($key)){$after[$key]}else{'[absent]'}
        if($b -cne $a){$result.Add([pscustomobject]@{location=$key;before=$b;after=$a})}
    }
    return @($result)
}
function Descendants([int]$rootPid){
    $procs=@(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId)
    $ids=[System.Collections.Generic.HashSet[int]]::new()
    [void]$ids.Add($rootPid)
    $change=$true
    while($change){
        $change=$false
        foreach($p in $procs){
            if($ids.Contains([int]$p.ParentProcessId) -and -not $ids.Contains([int]$p.ProcessId)){
                [void]$ids.Add([int]$p.ProcessId);$change=$true
            }
        }
    }
    return @($ids)
}
function IsLoopback([string]$address){
    if($address -in @('0.0.0.0','::','*')){return $true}
    $ip=$null
    if(-not [System.Net.IPAddress]::TryParse($address,[ref]$ip)){return $false}
    if([System.Net.IPAddress]::IsLoopback($ip)){return $true}
    if($ip.IsIPv4MappedToIPv6){return [System.Net.IPAddress]::IsLoopback($ip.MapToIPv4())}
    return $false
}
# Run on the GitHub Windows runner BEFORE compilation/downloads: this deliberately
# exercises the same HostFiles and diff functions used by the live gate.
if($SelfTest){
    $scratch = Join-Path $env:RUNNER_TEMP 'pdf-tunner-host-audit-selftest'
    if(Test-Path -LiteralPath $scratch){Remove-Item -LiteralPath $scratch -Recurse -Force}
    New-Item -Path $scratch -ItemType Directory -Force | Out-Null
    $hostPaths = @($scratch)
    try {
        $empty = HostFiles
        if(-not $empty.ContainsKey($scratch)){throw 'Self-test: missing root-directory snapshot.'}
        $sample = Join-Path $scratch 'test-file.txt'
        Set-Content -LiteralPath $sample -Value 'PDF_Tunner host audit self-test' -Encoding utf8
        $withFile = HostFiles
        if(-not $withFile.ContainsKey($sample)){throw 'Self-test: missing created-file snapshot.'}
        if($withFile[$scratch] -notlike '<DIR>|*'){throw 'Self-test: directory sentinel missing.'}
        $diff = @(Changes $empty $withFile)
        if(-not (@($diff | Where-Object { $_.location -eq $sample }).Count -eq 1)){
            throw 'Self-test: before/after file creation was not detected.'
        }
        if(-not (IsLoopback '127.0.0.1')){throw 'Self-test: loopback classified as external.'}
        if(IsLoopback '8.8.8.8'){throw 'Self-test: public address classified as loopback.'}
        $registry = RegistryState
        if($registry.Count -ne $regKeys.Count){throw 'Self-test: HKCU snapshot did not cover every requested key.'}
        Write-Host 'PASS: host boundary audit self-test (directory/file snapshots, diff, TCP classification, registry keys).'
    }finally{
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
    return
}

$beforeFiles=HostFiles
$beforeRegistry=RegistryState
$pids=[System.Collections.Generic.HashSet[int]]::new()
$connections=[System.Collections.Generic.List[object]]::new()
$proc=$null
$cleanup='not-started'
try{
    $oldPath=$env:PATH
    try{
        $win=$env:SystemRoot
        $env:PATH="$win\System32;$win;$win\System32\Wbem"
        $proc=Start-Process -FilePath $exe -WorkingDirectory $portable -PassThru
    }finally{$env:PATH=$oldPath}
    [void]$pids.Add([int]$proc.Id)
    $deadline=(Get-Date).AddSeconds($ObserveSeconds)
    while((Get-Date) -lt $deadline){
        foreach($pidValue in @(Descendants $proc.Id)){[void]$pids.Add([int]$pidValue)}
        $samples=@(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $pids.Contains([int]$_.OwningProcess) -and $_.RemotePort -gt 0 -and $_.State -ne 'Listen' })
        foreach($s in $samples){
            $connections.Add([pscustomobject]@{pid=[int]$s.OwningProcess;remote="$($s.RemoteAddress):$($s.RemotePort)";state=[string]$s.State;external=(-not (IsLoopback ([string]$s.RemoteAddress)))})
        }
        $proc.Refresh()
        if($proc.HasExited){break}
        Start-Sleep -Seconds 2
    }
}finally{
    if($null -ne $proc){
        try{
            $proc.Refresh()
            if(-not $proc.HasExited){
                [void]$proc.CloseMainWindow()
                if($proc.WaitForExit(20000)){$cleanup='graceful'}
                else{$cleanup='forced'; & taskkill.exe /PID $proc.Id /T /F | Out-Null}
            }else{$cleanup="exited-$($proc.ExitCode)"}
        }catch{$cleanup="cleanup-error: $($_.Exception.Message)"}
    }
    Start-Sleep -Seconds 2
    $files=@(Changes $beforeFiles (HostFiles))
    $registry=@(Changes $beforeRegistry (RegistryState))
    $external=@($connections | Where-Object { $_.external } | Sort-Object pid,remote -Unique)
    $report=[ordered]@{
        scope='Selected product AppData/TEMP paths and HKCU keys; process-tree TCP samples'
        portableRoot=$portable
        observedPids=@($pids | Sort-Object)
        sampleCount=$connections.Count
        externalTCP=$external
        hostFileChanges=$files
        hostRegistryChanges=$registry
        shutdown=$cleanup
        limitations=@('Not a kernel-level process trace or full filesystem/registry sandbox proof','Polling may miss transient writes or short TCP flows','DNS and UDP are not captured','The audit does not attribute changes to the process with certainty')
    }
    $out=Join-Path $reportDir 'portable-host-boundary-audit.json'
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $out -Encoding utf8
    Write-Host "Host boundary: TCP samples=$($connections.Count), external=$($external.Count), file changes=$($files.Count), registry changes=$($registry.Count); $cleanup"
    Write-Host "Report: $out"
    if($FailOnObservedEscape -and ($external.Count -gt 0 -or $files.Count -gt 0 -or $registry.Count -gt 0)){
        throw 'Scoped host-boundary gate detected external network or host write; inspect JSON.'
    }
}
