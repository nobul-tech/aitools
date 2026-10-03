# setup-modal.ps1 -- Installs/updates Modal CLI on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses uv tool (preferred) or pip --user (fallback). Requires Python 3.10+.
#
# Authentication (modal setup) is interactive and must be run separately
# after install -- not automated by this script.
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-modal"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# Helper: find Python user scripts directory and add to PATH if needed
function Ensure-PythonUserScriptsOnPath {
    if (-not $pythonCmd) { return }
    # nt_user scheme gives the user-install scripts directory on Windows.
    # Suppress stderr: an empty result skips the PATH update; the caller's modal PATH check reports it.
    $scriptsDir = & $pythonCmd -c "import sysconfig; print(sysconfig.get_path('scripts', 'nt_user'))" 2>$null
    if (-not $scriptsDir -or -not (Test-Path $scriptsDir)) { return }
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$scriptsDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$scriptsDir", "User")
        Log "Added Python user Scripts to persistent PATH: $scriptsDir"
    }
    if ($env:Path -notlike "*$scriptsDir*") {
        $env:Path = "$scriptsDir;$env:Path"
    }
}

# Log captured command output to the log file as detail lines (blank lines skipped).
function Write-OutputDetail([string]$Label, [string]$Output) {
    foreach ($l in $Output.Split("`n")) { if ($l.Trim()) { LogDetail "${Label}: $($l.TrimEnd())" } }
}

# Get-ModalVersion: `modal --version`. Python warnings print before the version line,
# so the last line is kept. A failed probe logs its output and returns "version
# unknown"; the install result is decided by the uv/pip exit code, not by this probe.
function Get-ModalVersion {
    $out = & modal --version 2>&1 | Out-String
    $rc = $LASTEXITCODE
    $lines = @($out.Split("`n") | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
    if ($rc -eq 0 -and $lines.Count -gt 0) { return $lines[-1] }
    Write-OutputDetail "modal-version (exit $rc)" $out
    return "version unknown"
}

# Refresh PATH to pick up tools installed by prior steps (e.g., setup-python, setup-uv)
Refresh-Path

# Verify Python 3.10+. Unlike setup-modal.sh (pip fallback only), this gate also runs
# when uv is present -- the Windows side of that change is pending validation on Windows.
$pythonCmd = $null
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCmd = "python"
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonCmd = "python3"
}

if ($pythonCmd) {
    $pyOutput = & $pythonCmd -c "import sys; print(str(sys.version_info.major) + '.' + str(sys.version_info.minor))" 2>&1 | Out-String
    $pyRc = $LASTEXITCODE
    $pyVersionStr = $pyOutput.Trim()
    if ($pyRc -eq 0 -and $pyVersionStr -match '^(\d+)\.(\d+)$') {
        $pyMajor = [int]$Matches[1]
        $pyMinor = [int]$Matches[2]
        if ($pyMajor -lt 3 -or ($pyMajor -eq 3 -and $pyMinor -lt 10)) {
            LogError "Python 3.10+ required. Found Python $pyVersionStr"
            Write-Summary "ERROR" "modal cli" "Python 3.10+ required (found $pyVersionStr)"
            exit 1
        }
        Log "Python $pyVersionStr found ($pythonCmd)"
    } else {
        Write-OutputDetail "python-version (exit $pyRc)" $pyOutput
        # Get-Command exempt: command-existence check with if/else fallback
        if (Get-Command uv -ErrorAction SilentlyContinue) {
            # uv provisions its own Python for the tool; only the pip fallback needs this one
            Log "Could not read the $pythonCmd version (exit $pyRc) -- continuing with uv"
        } else {
            LogError "Could not read the $pythonCmd version (exit $pyRc) -- see $logFile"
            Write-Summary "ERROR" "modal cli" "Python version check failed"
            exit 1
        }
    }
}

# --- Install/update ---
# Exit codes decide (C-F2); each command's full output goes to the log as detail.
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command uv -ErrorAction SilentlyContinue) {
    # Get-Command exempt: command-existence check with if/else fallback
    if (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = Get-ModalVersion
        LogOk "Modal CLI already installed ($modalVersion)"
        Log "Upgrading via uv tool..."
        $toolOutput = & uv tool upgrade modal 2>&1 | Out-String
        $toolRc = $LASTEXITCODE
        Write-OutputDetail "uv-tool-upgrade" $toolOutput
        if ($toolRc -ne 0 -and $toolOutput -match 'is not installed') {
            LogWarn "Modal was not installed via uv -- migrating to uv tool..."
            $toolOutput = & uv tool install modal 2>&1 | Out-String
            $toolRc = $LASTEXITCODE
            Write-OutputDetail "uv-tool-install" $toolOutput
        } elseif ($toolRc -ne 0 -and (Repair-UvToolEnv -ToolName "modal" -UpgradeOutput $toolOutput)) {
            $toolRc = 0
        }
        Refresh-Path
        # Get-Command exempt: command-existence check with if/else fallback
        if ($toolRc -ne 0) {
            LogError "uv tool install/upgrade modal failed (exit $toolRc) -- see $logFile"
            Write-Summary "ERROR" "modal cli" "uv tool install/upgrade failed (exit $toolRc)"
        } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
            $modalVersion = Get-ModalVersion
            LogOk "Modal CLI upgraded ($modalVersion)"
            Write-Summary "OK" "modal cli" "$modalVersion"
        } else {
            LogError "uv tool upgrade completed but 'modal' not found in PATH"
            Write-Summary "ERROR" "modal cli" "not on PATH after upgrade"
        }
    } else {
        Log "Installing Modal CLI via uv tool..."
        $toolOutput = & uv tool install modal 2>&1 | Out-String
        $toolRc = $LASTEXITCODE
        Write-OutputDetail "uv-tool-install" $toolOutput
        Refresh-Path
        # Get-Command exempt: command-existence check with if/else fallback
        if ($toolRc -ne 0) {
            LogError "uv tool install modal failed (exit $toolRc) -- see $logFile"
            Write-Summary "ERROR" "modal cli" "uv tool install failed (exit $toolRc)"
        } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
            $modalVersion = Get-ModalVersion
            $modalPath = (Get-Command modal).Source
            LogOk "Modal CLI installed ($modalVersion)"
            Log "Install path: $modalPath"
            Write-Summary "OK" "modal cli" "$modalVersion"
        } else {
            LogError "uv tool install completed but 'modal' not found in PATH"
            LogWarn "Ensure ~/.local/bin is in PATH"
            Write-Summary "ERROR" "modal cli" "installed but not on PATH"
        }
    }
} elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    $pipCmd = "pip"
    Log "uv not found -- installing Modal CLI via pip (--user)..."
    $pipOutput = & $pipCmd install --user modal 2>&1 | Out-String
    $pipRc = $LASTEXITCODE
    Write-OutputDetail "pip-install" $pipOutput
    Refresh-Path
    Ensure-PythonUserScriptsOnPath
    # Get-Command exempt: command-existence check with if/else fallback
    if ($pipRc -ne 0) {
        LogError "pip install --user modal failed (exit $pipRc) -- see $logFile"
        Write-Summary "ERROR" "modal cli" "pip install failed (exit $pipRc)"
    } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = Get-ModalVersion
        LogOk "Modal CLI installed ($modalVersion)"
        Write-Summary "OK" "modal cli" "$modalVersion"
    } else {
        LogError "pip install completed but 'modal' not found in PATH"
        Write-Summary "ERROR" "modal cli" "installed but not on PATH"
    }
} elseif ($pythonCmd) {
    # PEP 773: standalone pip deprecated on Windows; try python -m pip
    Log "uv and pip not found -- trying python -m pip (--user)..."
    $pipOutput = & $pythonCmd -m pip install --user modal 2>&1 | Out-String
    $pipRc = $LASTEXITCODE
    Write-OutputDetail "python-m-pip-install" $pipOutput
    Refresh-Path
    Ensure-PythonUserScriptsOnPath
    # Get-Command exempt: command-existence check with if/else fallback
    if ($pipRc -ne 0) {
        LogError "python -m pip install --user modal failed (exit $pipRc) -- see $logFile"
        Write-Summary "ERROR" "modal cli" "pip module install failed (exit $pipRc)"
    } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = Get-ModalVersion
        LogOk "Modal CLI installed ($modalVersion)"
        Write-Summary "OK" "modal cli" "$modalVersion"
    } else {
        LogError "python -m pip install completed but 'modal' not found in PATH"
        Write-Summary "ERROR" "modal cli" "installed but not on PATH"
    }
} else {
    LogError "No package installer found. Install uv or pip first."
    Write-Summary "ERROR" "modal cli" "no package installer (uv/pip) found"
}

# Only suggest auth if modal is installed but not yet authenticated
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command modal -ErrorAction SilentlyContinue) {
    $modalToml = Join-Path $HOME ".modal.toml"
    if (-not (Test-Path $modalToml)) {
        LogWarn "Authentication required: run 'modal setup' to authenticate (browser flow)"
        Write-Summary "WARN" "modal cli" "not authenticated"
        Write-Summary "ACTION" "" "modal setup -- authenticate modal (browser flow)"
    }
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile" "error"
    exit 1
} elseif ($warnings -gt 0) {
    Log "COMPLETED with $warnings warning(s)" "warn"
    exit 0
} else {
    Log "COMPLETED successfully" "ok"
    exit 0
}
