#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Hyperion Optimizer v2.0 - Advanced Roblox Process Optimizer
.DESCRIPTION
    Main = NEVER touched (full power always)
    Alts = Minimized + dedicated core affinity + memory trim
.NOTES
    Author: Hyperion | Requires Administrator
#>

# ══════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════
$Script:ConfigPath = Join-Path $PSScriptRoot "HyperionOptimizer.config.json"
$Script:Config = $null

function Load-Config {
    $defaults = [ordered]@{
        softRamLimitMB      = 500
        trimIntervalSeconds = 30
        pollIntervalMs      = 1000
        warmupMinutes       = 0.5
        minimizeAlts        = $true
        botCores            = 3
        killList            = @("RobloxCrashHandler.exe")
    }
    if (Test-Path $Script:ConfigPath) {
        try {
            $json = Get-Content $Script:ConfigPath -Raw | ConvertFrom-Json
            $propNames = @($json.PSObject.Properties.Name)
            foreach ($key in @($defaults.Keys)) {
                if ($key -in $propNames) {
                    $defaults[$key] = $json.$key
                }
            }
        } catch {
            Write-Warning "Config parse error, using defaults."
        }
    } else {
        $defaults | ConvertTo-Json -Depth 3 | Set-Content $Script:ConfigPath -Encoding UTF8
    }
    $Script:Config = $defaults
}

# ══════════════════════════════════════════════════════════════
# WIN32 API INTEROP
# ══════════════════════════════════════════════════════════════
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class WinAPI
{
    public const uint PROCESS_ALL = 0x001FFFFF;
    public const uint NORMAL_PRIORITY = 0x00000020;

    public const int SW_MINIMIZE  = 6;
    public const int SW_RESTORE   = 9;

    [StructLayout(LayoutKind.Sequential)]
    public struct MEM_COUNTERS
    {
        public uint cb;
        public uint PageFaultCount;
        public UIntPtr PeakWorkingSetSize;
        public UIntPtr WorkingSetSize;
        public UIntPtr QuotaPeakPagedPoolUsage;
        public UIntPtr QuotaPagedPoolUsage;
        public UIntPtr QuotaPeakNonPagedPoolUsage;
        public UIntPtr QuotaNonPagedPoolUsage;
        public UIntPtr PagefileUsage;
        public UIntPtr PeakPagefileUsage;
        public UIntPtr PrivateUsage;
    }

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr h);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetProcessWorkingSetSize(IntPtr h, IntPtr min, IntPtr max);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetProcessAffinityMask(IntPtr h, UIntPtr mask);

    [DllImport("psapi.dll")]
    public static extern bool GetProcessMemoryInfo(IntPtr h, out MEM_COUNTERS mem, uint cb);

    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr h);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    public delegate bool EnumWinProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWinProc cb, IntPtr lParam);

    // --- Helpers ---

    public static MEM_COUNTERS GetMemInfo(IntPtr h)
    {
        var m = new MEM_COUNTERS();
        m.cb = (uint)Marshal.SizeOf(m);
        GetProcessMemoryInfo(h, out m, m.cb);
        return m;
    }

    // Aggressive trim — since alts are minimized, this is safe
    // Minimized = ~1 FPS = very little active memory needed
    public static void AggressiveTrim(IntPtr h)
    {
        EmptyWorkingSet(h);
    }

    // Gentle trim — just reset bounds
    public static void GentleTrim(IntPtr h)
    {
        SetProcessWorkingSetSize(h, new IntPtr(-1), new IntPtr(-1));
    }

    // Find all visible windows belonging to a PID
    public static IntPtr[] GetPidWindows(uint targetPid)
    {
        var wins = new List<IntPtr>();
        EnumWindows((hWnd, lp) => {
            uint p; GetWindowThreadProcessId(hWnd, out p);
            if (p == targetPid && IsWindowVisible(hWnd)) wins.Add(hWnd);
            return true;
        }, IntPtr.Zero);
        return wins.ToArray();
    }

    // Get ALL windows (including minimized) for a PID
    public static IntPtr[] GetAllPidWindows(uint targetPid)
    {
        var wins = new List<IntPtr>();
        EnumWindows((hWnd, lp) => {
            uint p; GetWindowThreadProcessId(hWnd, out p);
            if (p == targetPid) wins.Add(hWnd);
            return true;
        }, IntPtr.Zero);
        return wins.ToArray();
    }

    public static void MinimizeProcess(uint pid)
    {
        var wins = GetPidWindows(pid);
        foreach (var w in wins) ShowWindow(w, SW_MINIMIZE);
    }

    public static void RestoreProcess(uint pid)
    {
        var wins = GetAllPidWindows(pid);
        foreach (var w in wins) ShowWindow(w, SW_RESTORE);
    }

    // Keep minimized — re-minimize if window pops back up
    public static bool IsProcessMinimized(uint pid)
    {
        var wins = GetAllPidWindows(pid);
        foreach (var w in wins) { if (!IsIconic(w)) return false; }
        return wins.Length > 0;
    }
}
"@ -ErrorAction Stop

# ══════════════════════════════════════════════════════════════
# GLOBAL STATE
# ══════════════════════════════════════════════════════════════
$Script:Instances     = @{}
$Script:MainPid       = $null
$Script:StartTime     = [DateTime]::UtcNow
$Script:BloatKilled   = 0
$Script:TotalRamSaved = 0
$Script:LogicalCores  = 0
$Script:SystemRam     = 0
$Script:IsWin11       = $false
$Script:NextCoreSlot  = 0

# ══════════════════════════════════════════════════════════════
# SYSTEM INFO
# ══════════════════════════════════════════════════════════════
function Initialize-SystemInfo {
    $Script:LogicalCores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $Script:SystemRam    = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $Script:IsWin11      = [System.Environment]::OSVersion.Version.Build -ge 22000
}

# ══════════════════════════════════════════════════════════════
# PROCESS MANAGEMENT
# ══════════════════════════════════════════════════════════════
function Find-RobloxPids {
    @(Get-Process -Name "RobloxPlayerBeta" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
}

function Register-Instance([int]$ProcId) {
    # Retry handle opening up to 3 times (fixes "refused to optimize" bug)
    $handle = [IntPtr]::Zero
    for ($retry = 0; $retry -lt 3; $retry++) {
        $handle = [WinAPI]::OpenProcess([WinAPI]::PROCESS_ALL, $false, [uint32]$ProcId)
        if ($handle -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 500
    }
    if ($handle -eq [IntPtr]::Zero) { return }

    $isMain = $false
    if ($null -eq $Script:MainPid) {
        $Script:MainPid = $ProcId
        $isMain = $true
    }

    $Script:Instances[$ProcId] = @{
        Handle       = $handle
        IsMain       = $isMain
        Throttled    = $false
        Minimized    = $false
        RegisteredAt = [DateTime]::UtcNow
        RamSaved     = 0
        RamMB        = 0
        Cores        = $Script:LogicalCores
    }

    if ($isMain) {
        $mem = [WinAPI]::GetMemInfo($handle)
        $Script:Instances[$ProcId].RamMB = [math]::Round([uint64]$mem.WorkingSetSize / 1MB, 0)
    }
}

function Unregister-Instance([int]$ProcId) {
    if (-not $Script:Instances.ContainsKey($ProcId)) { return }
    $inst = $Script:Instances[$ProcId]
    try { [void][WinAPI]::CloseHandle($inst.Handle) } catch {}

    if ($ProcId -eq $Script:MainPid) {
        $Script:MainPid = $null
        $Script:Instances.Remove($ProcId)
        $remaining = @($Script:Instances.Keys | Sort-Object)
        if ($remaining.Count -gt 0) {
            $newMain = $remaining[0]
            $Script:MainPid = $newMain
            $Script:Instances[$newMain].IsMain = $true
            if ($Script:Instances[$newMain].Minimized) {
                [WinAPI]::RestoreProcess([uint32]$newMain)
                $Script:Instances[$newMain].Minimized = $false
            }
        }
    } else {
        $Script:Instances.Remove($ProcId)
    }
}

# ══════════════════════════════════════════════════════════════
# WARMUP + THROTTLE (minimize + affinity after grace period)
# ══════════════════════════════════════════════════════════════
function Apply-WarmupCheck {
    $warmupSec = $Script:Config.warmupMinutes * 60
    foreach ($procId in @($Script:Instances.Keys)) {
        $inst = $Script:Instances[$procId]
        if ($inst.IsMain) { continue }
        if ($inst.Throttled) { continue }

        $elapsed = ([DateTime]::UtcNow - $inst.RegisteredAt).TotalSeconds
        if ($elapsed -ge $warmupSec) {
            # MINIMIZE — Roblox drops to ~1 FPS internally
            if ($Script:Config.minimizeAlts -and -not $inst.Minimized) {
                [WinAPI]::MinimizeProcess([uint32]$procId)
                $inst.Minimized = $true
            }

            # DEDICATED CORE AFFINITY — each bot gets its own cores (rotating)
            $botCores = [math]::Max(1, [math]::Min($Script:Config.botCores, $Script:LogicalCores))
            $startCore = $Script:NextCoreSlot
            $mask = 0
            for ($c = 0; $c -lt $botCores; $c++) {
                $coreIdx = ($startCore + $c) % $Script:LogicalCores
                $mask = $mask -bor (1 -shl $coreIdx)
            }
            $Script:NextCoreSlot = ($startCore + $botCores) % $Script:LogicalCores
            [void][WinAPI]::SetProcessAffinityMask($inst.Handle, [UIntPtr]::new($mask))
            $inst.Cores = $botCores

            $inst.Throttled = $true
        }
    }
}

# ══════════════════════════════════════════════════════════════
# KEEP MINIMIZED — re-minimize if a window pops back up
# ══════════════════════════════════════════════════════════════
function Enforce-Minimize {
    if (-not $Script:Config.minimizeAlts) { return }
    foreach ($procId in @($Script:Instances.Keys)) {
        $inst = $Script:Instances[$procId]
        if ($inst.IsMain -or -not $inst.Throttled) { continue }
        if ($inst.Minimized -and -not [WinAPI]::IsProcessMinimized([uint32]$procId)) {
            [WinAPI]::MinimizeProcess([uint32]$procId)
        }
    }
}

# ══════════════════════════════════════════════════════════════
# MEMORY TRIMMING
# ══════════════════════════════════════════════════════════════
function Invoke-MemoryTrim {
    foreach ($procId in @($Script:Instances.Keys)) {
        $inst = $Script:Instances[$procId]
        $h = $inst.Handle

        $memBefore = [WinAPI]::GetMemInfo($h)
        $wsBefore  = [uint64]$memBefore.WorkingSetSize
        $ramMB     = [math]::Round($wsBefore / 1MB, 0)

        # Only trim alts that are past warmup and over the soft limit
        if ((-not $inst.IsMain) -and $inst.Throttled) {
            $limitMB = $Script:Config.softRamLimitMB
            if ($ramMB -gt $limitMB) {
                # Since alt is minimized (~1 FPS), aggressive trim is safe
                if ($inst.Minimized) {
                    [WinAPI]::AggressiveTrim($h)
                } else {
                    [WinAPI]::GentleTrim($h)
                }

                $memAfter = [WinAPI]::GetMemInfo($h)
                $wsAfter  = [uint64]$memAfter.WorkingSetSize
                $ramMB    = [math]::Round($wsAfter / 1MB, 0)

                if ($wsBefore -gt $wsAfter) {
                    $saved = $wsBefore - $wsAfter
                    $inst.RamSaved += $saved
                    $Script:TotalRamSaved += $saved
                }
            }
        }

        $inst.RamMB = $ramMB
    }
}

# ══════════════════════════════════════════════════════════════
# BLOATWARE KILLER
# ══════════════════════════════════════════════════════════════
function Kill-Bloatware {
    foreach ($name in $Script:Config.killList) {
        $procName = [System.IO.Path]::GetFileNameWithoutExtension($name)
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            try {
                $p.Kill()
                $Script:BloatKilled++
            } catch {}
        }
    }
}

# ══════════════════════════════════════════════════════════════
# PROCESS SCANNER
# ══════════════════════════════════════════════════════════════
function Invoke-ProcessScan {
    $livePids = Find-RobloxPids

    foreach ($rPid in $livePids) {
        if (-not $Script:Instances.ContainsKey($rPid)) {
            Register-Instance $rPid
        }
    }

    foreach ($rPid in @($Script:Instances.Keys)) {
        if ($rPid -notin $livePids) {
            Unregister-Instance $rPid
        }
    }
}

# ══════════════════════════════════════════════════════════════
# DASHBOARD
# ══════════════════════════════════════════════════════════════
function Render-Dashboard {
    $uptime = ([DateTime]::UtcNow - $Script:StartTime)
    $uptimeStr = "{0:D2}:{1:D2}:{2:D2}" -f [int]$uptime.TotalHours, $uptime.Minutes, $uptime.Seconds
    $osLabel = if ($Script:IsWin11) { "Win11" } else { "Win10" }
    $ramSavedStr = if ($Script:TotalRamSaved -gt 1GB) {
        "{0:N2} GB" -f ($Script:TotalRamSaved / 1GB)
    } else {
        "{0:N0} MB" -f ($Script:TotalRamSaved / 1MB)
    }

    [Console]::SetCursorPosition(0, 0)

    $w = 76
    $border = [string]::new([char]0x2550, $w - 2)

    function Pad([string]$s, [int]$len) {
        if ($s.Length -ge $len) { return $s.Substring(0, $len) }
        return $s + (' ' * ($len - $s.Length))
    }

    function Row([string]$content) {
        $padded = Pad $content ($w - 4)
        Write-Host "$([char]0x2551) $padded $([char]0x2551)"
    }

    Write-Host "$([char]0x2554)$border$([char]0x2557)"
    Row "  $([char]0x26A1) HYPERION OPTIMIZER v2.0                            [$osLabel]"
    Write-Host "$([char]0x2560)$border$([char]0x2563)"
    Row "  CPU: $($Script:LogicalCores) cores | RAM: $($Script:SystemRam) GB | Uptime: $uptimeStr"
    Write-Host "$([char]0x2560)$border$([char]0x2563)"

    $hdr = "  {0,-8}{1,-12}{2,-10}{3,-8}{4,-12}{5,-10}" -f "PID", "STATUS", "RAM(MB)", "CORES", "WINDOW", "SAVED"
    Row $hdr
    Write-Host "$([char]0x2551)$([string]::new([char]0x2500, $w - 2))$([char]0x2551)"

    if ($Script:Instances.Count -eq 0) {
        Row "  Waiting for Roblox... Open your MAIN account first!"
        Row ""
        Row ""
    } else {
        $shown = 0
        foreach ($procId in ($Script:Instances.Keys | Sort-Object)) {
            $inst = $Script:Instances[$procId]
            $savedStr = $null

            if ($inst.IsMain) {
                $status = "$([char]0x2605) MAIN"
                $winState = "FULL"
            } elseif (-not $inst.Throttled) {
                $elapsed = ([DateTime]::UtcNow - $inst.RegisteredAt).TotalSeconds
                $remaining = [math]::Max(0, ($Script:Config.warmupMinutes * 60) - $elapsed)
                $remStr = "{0:N0}s" -f $remaining
                $status = "LOADING"
                $winState = "FULL"
                $savedStr = "wait $remStr"
            } else {
                $status = "$([char]0x2699) ALT"
                $winState = if ($inst.Minimized) { "MINIMIZED" } else { "VISIBLE" }
            }

            if (-not $savedStr) {
                $savedStr = if ($inst.RamSaved -gt 0) { "{0:N0} MB" -f ($inst.RamSaved / 1MB) } else { "-" }
            }

            $coresStr = "$($inst.Cores)/$($Script:LogicalCores)"
            $line = "  {0,-8}{1,-12}{2,-10}{3,-8}{4,-12}{5,-10}" -f $procId, $status, $inst.RamMB, $coresStr, $winState, $savedStr
            Row $line
            $shown++
        }
        for ($i = $shown; $i -lt 3; $i++) { Row "" }
    }

    Write-Host "$([char]0x2560)$border$([char]0x2563)"
    Row "  RAM Saved: $ramSavedStr | Bloat Killed: $($Script:BloatKilled) | Instances: $($Script:Instances.Count)"
    Write-Host "$([char]0x255A)$border$([char]0x255D)"
    Write-Host "  Main=untouched | Alts=minimized+trimmed | Use HyperionCleanup.lua  "
    Write-Host "  Press Ctrl+C to stop.                                              "
}

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
function Main {
    Load-Config
    Initialize-SystemInfo

    Clear-Host
    [Console]::CursorVisible = $false

    $lastScan     = [DateTime]::MinValue
    $lastTrim     = [DateTime]::MinValue
    $lastDash     = [DateTime]::MinValue
    $lastMinCheck = [DateTime]::MinValue

    try {
        while ($true) {
            $now = [DateTime]::UtcNow

            if (($now - $lastScan).TotalMilliseconds -ge $Script:Config.pollIntervalMs) {
                Invoke-ProcessScan
                Apply-WarmupCheck
                $lastScan = $now
            }

            if (($now - $lastTrim).TotalSeconds -ge $Script:Config.trimIntervalSeconds) {
                Invoke-MemoryTrim
                Kill-Bloatware
                $lastTrim = $now
            }

            # Re-minimize check every 5 seconds
            if (($now - $lastMinCheck).TotalSeconds -ge 5) {
                Enforce-Minimize
                $lastMinCheck = $now
            }

            if (($now - $lastDash).TotalMilliseconds -ge 1000) {
                Render-Dashboard
                $lastDash = $now
            }

            Start-Sleep -Milliseconds 200
        }
    }
    finally {
        foreach ($procId in @($Script:Instances.Keys)) {
            $inst = $Script:Instances[$procId]
            try {
                if ($inst.Minimized) {
                    [WinAPI]::RestoreProcess([uint32]$procId)
                }
                [void][WinAPI]::CloseHandle($inst.Handle)
            } catch {}
        }
        [Console]::CursorVisible = $true
        Write-Host "`n`n  Hyperion Optimizer stopped. All alt windows restored."
    }
}

Main
