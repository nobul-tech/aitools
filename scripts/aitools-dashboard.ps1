# aitools-dashboard.ps1 -- Mission control dashboard lifecycle management (Windows)
# Safe to re-run. Manages the live dashboard server for running estimates.
#
# Usage:
#   pwsh -File scripts/aitools-dashboard.ps1 [OPTIONS]
#
# Options:
#   -Background         Start server in background (for hooks)
#   -Stop               Stop the running server
#   -Status             Show server status
#   -Snapshot           Generate static HTML snapshot
#   -Port PORT          Custom port (default: 8411)
#   -Estimate PATH      Explicit estimate path (default: auto-detect)
#
# Called by: aitools dashboard (entry point dispatch)
# Called by: SessionStart hook (dashboard-serve.sh) via aitools dashboard --background
# See: reference/tool-registry.md (Python managed tool)

param(
    [switch]$Background,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Snapshot,
    [switch]$OpenBrowser,
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
# PID file location
# ---------------------------------------------------------------------------
$pidDir = Join-Path $ProjectRoot ".aitools"
if (-not (Test-Path $pidDir)) {
    try { New-Item -ItemType Directory -Path $pidDir -Force | Out-Null } catch {
        $pidDir = $env:TEMP
    }
}
$pidFile = Join-Path $pidDir ".dashboard-pid"

# ---------------------------------------------------------------------------
# Find python
# ---------------------------------------------------------------------------
function Find-Python {
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return "python3" }
    if (Get-Command python -ErrorAction SilentlyContinue) { return "python" }
    return $null
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
# Check if server is running
# ---------------------------------------------------------------------------
function Get-ServerPid {
    if (Test-Path $pidFile) {
        $pidStr = Get-Content $pidFile -Raw -ErrorAction SilentlyContinue
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
        Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
    }
    return $null
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
# ACTION: Status
# ---------------------------------------------------------------------------
if ($Status) {
    $pid = Get-ServerPid
    if ($pid) {
        LogOk "Dashboard server running (PID $pid) on port $Port"
        Log "URL: http://localhost:$Port/"
        Log "PID file: $pidFile"
    } else {
        Log "Dashboard server is not running"
        if (Test-PortInUse -TestPort $Port) {
            LogWarn "Port $Port is in use by another process"
        }
    }
    exit 0
}

# ---------------------------------------------------------------------------
# ACTION: Stop
# ---------------------------------------------------------------------------
if ($Stop) {
    $pid = Get-ServerPid
    if ($pid) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        } catch {}
        Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        LogOk "Dashboard server stopped (PID $pid)"
    } else {
        Log "Dashboard server is not running"
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

# Check if already running
$existingPid = Get-ServerPid
if ($existingPid) {
    Log "Dashboard server already running (PID $existingPid)"
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

if ($Background) {
    # Background mode: Start-Process for detached process
    $proc = Start-Process -FilePath $python -ArgumentList @(
        "$generator", "--estimate", "$Estimate", "--serve", "--port", "$Port"
    ) -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue

    if ($proc) {
        # Write PID for cleanup
        Set-Content -Path $pidFile -Value $proc.Id -NoNewline

        # Brief pause to let the server bind
        Start-Sleep -Milliseconds 300

        # Verify server started
        try {
            $check = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($check) {
                LogOk "Dashboard server started in background (PID $($proc.Id))"
                Log "URL: http://localhost:$Port/"
                Write-Summary "OK" "dashboard" "http://localhost:$Port/"
            } else {
                Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
                LogError "Dashboard server failed to start"
                Write-Summary "ERROR" "dashboard" "failed to start"
                exit 1
            }
        } catch {
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
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
    Set-Content -Path $pidFile -Value $PID -NoNewline

    # Register cleanup
    $cleanupBlock = {
        if (Test-Path $pidFile) {
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        }
    }
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupBlock | Out-Null

    $genArgs = @("$generator", "--estimate", "$Estimate", "--serve", "--port", "$Port")
    if ($OpenBrowser) { $genArgs += "--open" }

    Write-Summary "OK" "dashboard" "http://localhost:$Port/"
    & $python @genArgs
}
