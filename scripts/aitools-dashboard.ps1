# aitools-dashboard.ps1 -- Mission control dashboard lifecycle management (Windows)
# Safe to re-run. Manages the live dashboard server for running estimates.
#
# Usage:
#   pwsh -File scripts/aitools-dashboard.ps1 [OPTIONS]
#
# Options:
#   -Background         Start server in background (for hooks)
#   -Stop               Stop running server(s)
#     -Port PORT          Stop specific port only
#     -All                Stop all instances
#   -Status             Show all running instances with health
#   -HealthCheck        Liveness + data quality check for all instances
#   -Snapshot           Generate static HTML snapshot
#   -Port PORT          Custom port (default: 8411)
#   -Estimate PATH      Explicit estimate path (default: auto-detect)
#
# Multi-instance: PID files stored in ~/.aitools/dashboard-pids/<port>.pid
#
# Called by: aitools dashboard (entry point dispatch)
# Called by: SessionStart hook (dashboard-serve.sh) via aitools dashboard --background
# See: reference/tool-registry.md (Python managed tool)

param(
    [switch]$Background,
    [switch]$Stop,
    [switch]$Status,
    [switch]$HealthCheck,
    [switch]$Snapshot,
    [switch]$OpenBrowser,
    [switch]$All,
    [int]$Port = 8411,
    [string]$Estimate = "",
    [string]$ProjectRoot = ""
)

# --- Shared library ---
. (Join-Path $PSScriptRoot "aitools-lib.ps1")
Initialize-Logging "aitools-dashboard"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use aitools-dashboard.sh instead."
    exit 1
}

# ---------------------------------------------------------------------------
# Resolve project root
# ---------------------------------------------------------------------------
if (-not $ProjectRoot) {
    try {
        $ProjectRoot = git rev-parse --show-toplevel 2>$null
    } catch {}
    if (-not $ProjectRoot) { $ProjectRoot = Get-Location }
}

# ---------------------------------------------------------------------------
# PID registry directory (multi-instance)
# ---------------------------------------------------------------------------
$pidRegistryDir = Join-Path $env:USERPROFILE ".aitools\dashboard-pids"
if (-not (Test-Path $pidRegistryDir)) {
    try { New-Item -ItemType Directory -Path $pidRegistryDir -Force | Out-Null } catch {}
}

# Legacy PID file location (for migration)
$legacyPidDir = Join-Path $ProjectRoot ".aitools"
$legacyPidFile = Join-Path $legacyPidDir ".dashboard-pid"

# ---------------------------------------------------------------------------
# Find python
# ---------------------------------------------------------------------------
function Find-Python {
    # Delegate to the harness resolver (prefers the uv shim deterministically).
    Get-HarnessPython
}

# ---------------------------------------------------------------------------
# Find the generator script
# ---------------------------------------------------------------------------
function Find-Generator {
    $configFile = Join-Path $env:USERPROFILE ".aitools\config.json"
    $repoPath = ReadConfigKey -File $configFile -Key "repoPath"
    if (-not $repoPath) { $repoPath = Join-Path $env:USERPROFILE "repos\aitools" }

    $genPath = Join-Path $repoPath "scripts\generate-dashboard.py"
    if (Test-Path $genPath) { return $genPath }

    $genPath = Join-Path $ProjectRoot "scripts\generate-dashboard.py"
    if (Test-Path $genPath) { return $genPath }

    return $null
}

# ---------------------------------------------------------------------------
# Auto-detect running estimate
# ---------------------------------------------------------------------------
function Find-Estimate {
    # 1. Check .aitools/channel/ for tracked running estimate
    $tracked = Join-Path $ProjectRoot ".aitools\channel\running-estimate.json"
    if (Test-Path $tracked) { return $tracked }

    # 2. Check session-specific channel dirs
    $channelDir = Join-Path $ProjectRoot ".aitools\channel"
    if (Test-Path $channelDir) {
        $sessionDirs = Get-ChildItem -Path $channelDir -Directory -Filter "session-*" -ErrorAction SilentlyContinue
        foreach ($dir in $sessionDirs) {
            $estimates = Get-ChildItem -Path $dir.FullName -Filter "*running-estimate*.json" -File -ErrorAction SilentlyContinue
            if ($estimates) { return $estimates[0].FullName }
        }
    }

    # 3. Check .scratch/ for session estimates (most recently modified)
    $scratchDir = Join-Path $ProjectRoot ".scratch"
    if (Test-Path $scratchDir) {
        $best = $null
        $sessionDirs = Get-ChildItem -Path $scratchDir -Directory -Filter "session-*" -ErrorAction SilentlyContinue
        foreach ($dir in $sessionDirs) {
            $estimates = Get-ChildItem -Path $dir.FullName -Filter "*running-estimate*.json" -File -ErrorAction SilentlyContinue
            foreach ($est in $estimates) {
                if (-not $best -or $est.LastWriteTime -gt $best.LastWriteTime) {
                    $best = $est
                }
            }
        }
        if ($best) { return $best.FullName }
    }

    # 4. Check .aitools/scratch/ (workspace namespace)
    $asScratchDir = Join-Path $ProjectRoot ".aitools\scratch"
    if (Test-Path $asScratchDir) {
        $best = $null
        $sessionDirs = Get-ChildItem -Path $asScratchDir -Directory -Filter "session-*" -ErrorAction SilentlyContinue
        foreach ($dir in $sessionDirs) {
            $estimates = Get-ChildItem -Path $dir.FullName -Filter "*running-estimate*.json" -File -ErrorAction SilentlyContinue
            foreach ($est in $estimates) {
                if (-not $best -or $est.LastWriteTime -gt $best.LastWriteTime) {
                    $best = $est
                }
            }
        }
        if ($best) { return $best.FullName }
    }

    return $null
}

# ---------------------------------------------------------------------------
# PID registry helpers (multi-instance)
# ---------------------------------------------------------------------------

function Get-PidFileForPort {
    param([int]$PortNum)
    return Join-Path $pidRegistryDir "$PortNum.pid"
}

function Get-PortServerPid {
    param([int]$PortNum)
    $pf = Get-PidFileForPort -PortNum $PortNum
    if (Test-Path $pf) {
        $pidStr = Get-Content $pf -Raw -ErrorAction SilentlyContinue
        if ($pidStr) {
            $pidStr = $pidStr.Trim()
            $pidInt = 0
            if ([int]::TryParse($pidStr, [ref]$pidInt)) {
                try {
                    $proc = Get-Process -Id $pidInt -ErrorAction SilentlyContinue
                    if ($proc) { return $pidInt }
                } catch {}
            }
        }
        # Stale PID file -- clean up
        Remove-Item -Path $pf -Force -ErrorAction SilentlyContinue
    }
    return $null
}

function Invoke-LegacyMigration {
    if (Test-Path $legacyPidFile) {
        $pidStr = Get-Content $legacyPidFile -Raw -ErrorAction SilentlyContinue
        if ($pidStr) {
            $pidStr = $pidStr.Trim()
            $pidInt = 0
            if ([int]::TryParse($pidStr, [ref]$pidInt)) {
                try {
                    $proc = Get-Process -Id $pidInt -ErrorAction SilentlyContinue
                    if ($proc) {
                        $newPf = Get-PidFileForPort -PortNum 8411
                        if (-not (Test-Path $newPf)) {
                            Copy-Item $legacyPidFile $newPf
                            Log "Migrated legacy PID $pidInt to port registry (8411)"
                        }
                    }
                } catch {}
            }
        }
        Remove-Item -Path $legacyPidFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-RunningInstances {
    $instances = @()
    $pidFiles = Get-ChildItem -Path $pidRegistryDir -Filter "*.pid" -File -ErrorAction SilentlyContinue
    foreach ($pf in $pidFiles) {
        $portName = $pf.BaseName
        $pidStr = Get-Content $pf.FullName -Raw -ErrorAction SilentlyContinue
        if ($pidStr) {
            $pidStr = $pidStr.Trim()
            $pidInt = 0
            if ([int]::TryParse($pidStr, [ref]$pidInt)) {
                try {
                    $proc = Get-Process -Id $pidInt -ErrorAction SilentlyContinue
                    if ($proc) {
                        $instances += [PSCustomObject]@{ Port = $portName; Pid = $pidInt }
                    } else {
                        Remove-Item -Path $pf.FullName -Force -ErrorAction SilentlyContinue
                    }
                } catch {
                    Remove-Item -Path $pf.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    return $instances
}

# ---------------------------------------------------------------------------
# Check if port is in use
# ---------------------------------------------------------------------------
function Test-PortInUse {
    param([int]$TestPort)
    try {
        $connections = Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue
        return ($null -ne $connections -and @($connections).Count -gt 0)
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------------
# Health check helper: check one instance
# ---------------------------------------------------------------------------
function Test-InstanceHealth {
    param([int]$InstPort, [int]$InstPid)
    $healthy = $true
    $details = ""

    # 1. HTTP liveness check
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$InstPort/" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -ne 200) {
            $healthy = $false
            $details = "HTTP $($response.StatusCode) (expected 200)"
        }
    } catch {
        $healthy = $false
        $details = "HTTP request failed"
    }

    # 2. Data quality check: read the estimate via API
    $estimateJson = $null
    try {
        $apiResponse = Invoke-WebRequest -Uri "http://localhost:$InstPort/api/estimate" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($apiResponse.StatusCode -eq 200) {
            $estimateJson = $apiResponse.Content
        }
    } catch {}

    if ($estimateJson) {
        try {
            $d = $estimateJson | ConvertFrom-Json
            $missing = @()
            foreach ($f in @("delegationLog", "findings", "openThreads")) {
                if (-not ($d.PSObject.Properties.Name -contains $f)) {
                    $missing += $f
                }
            }
            if (-not ($d.PSObject.Properties.Name -contains "situation")) {
                $missing += "situation"
            } elseif ($d.situation) {
                foreach ($f in @("decisions", "assumptions", "deviations", "facts")) {
                    if (-not ($d.situation.PSObject.Properties.Name -contains $f)) {
                        $missing += "situation.$f"
                    }
                }
            }

            $delCount = @($d.delegationLog).Count
            $findCount = @($d.findings).Count
            $threadCount = @($d.openThreads).Count

            if ($missing.Count -gt 0) {
                $healthy = $false
                $missingStr = $missing -join ", "
                $details = "$details, missing fields: $missingStr ($delCount delegations, $findCount findings, $threadCount threads)".TrimStart(", ")
            } else {
                $details = "$details, $delCount delegations, $findCount findings, $threadCount threads".TrimStart(", ")
            }
        } catch {
            $details = "$details, estimate JSON parse error".TrimStart(", ")
            $healthy = $false
        }
    } elseif ($healthy) {
        $details = "$details, no /api/estimate endpoint (static mode?)".TrimStart(", ")
    }

    if ($healthy) {
        LogOk "Dashboard on port ${InstPort}: HEALTHY ($details)"
    } else {
        LogWarn "Dashboard on port ${InstPort}: UNHEALTHY ($details)"
    }

    return $healthy
}

# ---------------------------------------------------------------------------
# Migrate legacy PID file
# ---------------------------------------------------------------------------
Invoke-LegacyMigration

# ---------------------------------------------------------------------------
# ACTION: Status
# ---------------------------------------------------------------------------
if ($Status) {
    $instances = Get-RunningInstances
    if ($instances.Count -eq 0) {
        Log "No dashboard instances running"
        if (Test-PortInUse -TestPort $Port) {
            LogWarn "Port $Port is in use by another process (not a managed dashboard)"
        }
    } else {
        foreach ($inst in $instances) {
            LogOk "Dashboard server running (PID $($inst.Pid)) on port $($inst.Port)"
            Log "  URL: http://localhost:$($inst.Port)/"
            Log "  PID file: $(Get-PidFileForPort -PortNum $inst.Port)"
        }
    }
    exit 0
}

# ---------------------------------------------------------------------------
# ACTION: HealthCheck
# ---------------------------------------------------------------------------
if ($HealthCheck) {
    $instances = Get-RunningInstances
    if ($instances.Count -eq 0) {
        LogWarn "No dashboard instances running"
        exit 1
    }
    $unhealthy = 0
    foreach ($inst in $instances) {
        $result = Test-InstanceHealth -InstPort $inst.Port -InstPid $inst.Pid
        if (-not $result) { $unhealthy++ }
    }
    if ($unhealthy -gt 0) { exit 1 }
    exit 0
}

# ---------------------------------------------------------------------------
# ACTION: Stop
# ---------------------------------------------------------------------------
if ($Stop) {
    if ($All) {
        # Stop all instances
        $instances = Get-RunningInstances
        if ($instances.Count -eq 0) {
            Log "No dashboard instances running"
        } else {
            foreach ($inst in $instances) {
                try {
                    Stop-Process -Id $inst.Pid -Force -ErrorAction SilentlyContinue
                } catch {}
                $pf = Get-PidFileForPort -PortNum $inst.Port
                Remove-Item -Path $pf -Force -ErrorAction SilentlyContinue
                LogOk "Stopped dashboard on port $($inst.Port) (PID $($inst.Pid))"
            }
        }
    } else {
        # Stop specific port
        $pid = Get-PortServerPid -PortNum $Port
        if ($pid) {
            try {
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            } catch {}
            $pf = Get-PidFileForPort -PortNum $Port
            Remove-Item -Path $pf -Force -ErrorAction SilentlyContinue
            LogOk "Stopped dashboard on port $Port (PID $pid)"
        } else {
            Log "No dashboard running on port $Port"
        }
    }
    exit 0
}

# ---------------------------------------------------------------------------
# ACTION: Snapshot
# ---------------------------------------------------------------------------
if ($Snapshot) {
    $python = Find-Python
    if (-not $python) {
        LogError "python not found -- install Python to use the dashboard"
        Write-Summary "ERROR" "dashboard" "python not found"
        exit 1
    }

    $generator = Find-Generator
    if (-not $generator) {
        LogError "generate-dashboard.py not found"
        Write-Summary "ERROR" "dashboard" "generator not found"
        exit 1
    }

    if (-not $Estimate) {
        $Estimate = Find-Estimate
        if (-not $Estimate) {
            LogError "no running estimate found"
            Write-Summary "WARN" "dashboard" "no estimate found"
            exit 1
        }
    }

    Log "Generating static dashboard snapshot..."
    $genArgs = @("$generator", "--estimate", "$Estimate")
    if ($OpenBrowser) { $genArgs += "--open" }

    $result = & $python @genArgs 2>&1
    if ($LASTEXITCODE -eq 0) {
        LogOk "Dashboard snapshot generated"
        Write-Summary "OK" "dashboard" "snapshot generated"
    } else {
        LogError "Dashboard generation failed"
        Write-Summary "ERROR" "dashboard" "generation failed"
        exit 1
    }
    exit 0
}

# ---------------------------------------------------------------------------
# ACTION: Start (default)
# ---------------------------------------------------------------------------

# Check if this port already has a running instance
$existingPid = Get-PortServerPid -PortNum $Port
if ($existingPid) {
    Log "Dashboard server already running on port $Port (PID $existingPid)"
    if (-not $Background) {
        Log "URL: http://localhost:$Port/"
    }
    Write-Summary "OK" "dashboard" "http://localhost:$Port/ (already running)"
    exit 0
}

# Check if port is in use by something else
if (Test-PortInUse -TestPort $Port) {
    LogWarn "Port $Port is already in use by another process"
    Write-Summary "WARN" "dashboard" "port $Port in use"
    exit 1
}

# Find dependencies
$python = Find-Python
if (-not $python) {
    LogError "python not found -- install Python to use the dashboard"
    Write-Summary "ERROR" "dashboard" "python not found"
    exit 1
}

$generator = Find-Generator
if (-not $generator) {
    LogError "generate-dashboard.py not found"
    Write-Summary "ERROR" "dashboard" "generator not found"
    exit 1
}

# Resolve estimate path
if (-not $Estimate) {
    $Estimate = Find-Estimate
    if (-not $Estimate) {
        if ($Background) {
            # Background mode: no estimate is not an error, just skip
            exit 0
        }
        LogError "no running estimate found"
        Log "Create a running estimate in .aitools\channel\running-estimate.json or .scratch\session-*\running-estimate*.json"
        Write-Summary "WARN" "dashboard" "no estimate found"
        exit 1
    }
}

Log "Starting dashboard server on port $Port..."
Log "Estimate: $Estimate"

$portPidFile = Get-PidFileForPort -PortNum $Port

if ($Background) {
    # Background mode: Start-Process for detached process
    $proc = Start-Process -FilePath $python -ArgumentList @(
        "$generator", "--estimate", "$Estimate", "--serve", "--port", "$Port"
    ) -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue

    if ($proc) {
        # Write PID to port-keyed registry
        Set-Content -Path $portPidFile -Value $proc.Id -NoNewline

        # Brief pause to let the server bind
        Start-Sleep -Milliseconds 300

        # Verify server started
        try {
            $check = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($check) {
                LogOk "Dashboard server started in background (PID $($proc.Id)) on port $Port"
                Log "URL: http://localhost:$Port/"
                Write-Summary "OK" "dashboard" "http://localhost:$Port/"
            } else {
                Remove-Item -Path $portPidFile -Force -ErrorAction SilentlyContinue
                LogError "Dashboard server failed to start"
                Write-Summary "ERROR" "dashboard" "failed to start"
                exit 1
            }
        } catch {
            Remove-Item -Path $portPidFile -Force -ErrorAction SilentlyContinue
            LogError "Dashboard server failed to start"
            Write-Summary "ERROR" "dashboard" "failed to start"
            exit 1
        }
    } else {
        LogError "Failed to launch dashboard server process"
        Write-Summary "ERROR" "dashboard" "launch failed"
        exit 1
    }
} else {
    # Foreground mode: server runs until Ctrl+C
    Set-Content -Path $portPidFile -Value $PID -NoNewline

    # Register cleanup
    $cleanupBlock = {
        if (Test-Path $portPidFile) {
            Remove-Item -Path $portPidFile -Force -ErrorAction SilentlyContinue
        }
    }
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupBlock | Out-Null

    $genArgs = @("$generator", "--estimate", "$Estimate", "--serve", "--port", "$Port")
    if ($OpenBrowser) { $genArgs += "--open" }

    Write-Summary "OK" "dashboard" "http://localhost:$Port/"
    & $python @genArgs
}
