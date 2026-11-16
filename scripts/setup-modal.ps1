# setup-modal.ps1 -- Installs/updates Modal CLI on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses uv tool (preferred) or pip --user (fallback). Requires Python 3.10+.
#
# Authentication (modal setup) is interactive and must be run separately
# after install -- not automated by this script.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
            Write-AitError "modal cli" "Python 3.10+ required" "found Python $pyVersionStr"
            exit 1
        }
        Log "Python $pyVersionStr found ($pythonCmd)"
    } else {
        # Get-Command exempt: command-existence check with if/else fallback
        if (Get-Command uv -ErrorAction SilentlyContinue) {
            Write-OutputDetail "python-version (exit $pyRc)" $pyOutput
            # uv provisions its own Python for the tool; only the pip fallback needs this one
            Log "Could not read the $pythonCmd version (exit $pyRc) -- continuing with uv"
        } else {
            # Get-AitErrorReason logs the output as detail lines
            Write-AitError "modal cli" "Python version check failed" (Get-AitErrorReason -Output $pyOutput -ExitCode $pyRc)
            exit 1
        }
    }
}

# --- Install/update ---
# Exit codes decide (C-F2). A command's output goes to the log as detail; a failed
# command's output is passed to Get-AitErrorReason instead, which logs it (logging.md 8.2).
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command uv -ErrorAction SilentlyContinue) {
    # Get-Command exempt: command-existence check with if/else fallback
    if (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = Get-ModalVersion
        LogOk "Modal CLI already installed ($modalVersion)"
        Log "Upgrading via uv tool..."
        $toolOutput = & uv tool upgrade modal 2>&1 | Out-String
        $toolRc = $LASTEXITCODE
        # Repair-UvToolEnv: 0 repaired, 1 not applicable, 3 failed and already recorded
        $repairRc = 1
        if ($toolRc -eq 0) {
            Write-OutputDetail "uv-tool-upgrade" $toolOutput
        } elseif ($toolOutput -match 'is not installed') {
            Write-OutputDetail "uv-tool-upgrade (exit $toolRc)" $toolOutput
            Write-AitWarn "modal cli" "not installed with uv -- migrating to uv tool"
            $toolOutput = & uv tool install modal 2>&1 | Out-String
            $toolRc = $LASTEXITCODE
            if ($toolRc -eq 0) { Write-OutputDetail "uv-tool-install" $toolOutput }
        } else {
            $repairRc = Repair-UvToolEnv -ToolName "modal" -UpgradeOutput $toolOutput -Tool "modal cli"
            if ($repairRc -ne 1) { Write-OutputDetail "uv-tool-upgrade (exit $toolRc)" $toolOutput }
            if ($repairRc -eq 0) { $toolRc = 0 }
        }
        Refresh-Path
        # Get-Command exempt: command-existence check with if/else fallback
        if ($toolRc -ne 0) {
            # A failed repair (3) is already recorded by the library: no second record
            if ($repairRc -ne 3) {
                Write-AitError "modal cli" "uv tool install/upgrade failed" (Get-AitErrorReason -Output $toolOutput -ExitCode $toolRc)
            }
        } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
            $modalVersion = Get-ModalVersion
            LogOk "Modal CLI upgraded ($modalVersion)"
            Write-Summary "OK" "modal cli" "$modalVersion"
        } else {
            Write-AitError "modal cli" "not on PATH after upgrade" "modal not found on PATH after uv tool upgrade"
        }
    } else {
        Log "Installing Modal CLI via uv tool..."
        $toolOutput = & uv tool install modal 2>&1 | Out-String
        $toolRc = $LASTEXITCODE
        if ($toolRc -eq 0) { Write-OutputDetail "uv-tool-install" $toolOutput }
        Refresh-Path
        # Get-Command exempt: command-existence check with if/else fallback
        if ($toolRc -ne 0) {
            Write-AitError "modal cli" "uv tool install failed" (Get-AitErrorReason -Output $toolOutput -ExitCode $toolRc)
        } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
            $modalVersion = Get-ModalVersion
            $modalPath = (Get-Command modal).Source
            LogOk "Modal CLI installed ($modalVersion)"
            Log "Install path: $modalPath"
            Write-Summary "OK" "modal cli" "$modalVersion"
        } else {
            # Not on PATH is an error, with the remedy as an ACTION (Standard 4)
            Write-AitError "modal cli" "installed but not on PATH" "modal not found after uv tool install"
            Write-Summary "ACTION" "" "Add the directory 'uv tool dir --bin' prints to PATH -- modal not accessible"
        }
    }
} elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    $pipCmd = "pip"
    Log "uv not found -- installing Modal CLI via pip (--user)..."
    $pipOutput = & $pipCmd install --user modal 2>&1 | Out-String
    $pipRc = $LASTEXITCODE
    if ($pipRc -eq 0) { Write-OutputDetail "pip-install" $pipOutput }
    Refresh-Path
    Ensure-PythonUserScriptsOnPath
    # Get-Command exempt: command-existence check with if/else fallback
    if ($pipRc -ne 0) {
        Write-AitError "modal cli" "pip install failed" (Get-AitErrorReason -Output $pipOutput -ExitCode $pipRc)
    } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = Get-ModalVersion
        LogOk "Modal CLI installed ($modalVersion)"
        Write-Summary "OK" "modal cli" "$modalVersion"
    } else {
        Write-AitError "modal cli" "installed but not on PATH" "modal not found after pip install --user"
    }
} elseif ($pythonCmd) {
    # PEP 773: standalone pip deprecated on Windows; try python -m pip
    Log "uv and pip not found -- trying python -m pip (--user)..."
    $pipOutput = & $pythonCmd -m pip install --user modal 2>&1 | Out-String
    $pipRc = $LASTEXITCODE
    if ($pipRc -eq 0) { Write-OutputDetail "python-m-pip-install" $pipOutput }
    Refresh-Path
    Ensure-PythonUserScriptsOnPath
    # Get-Command exempt: command-existence check with if/else fallback
    if ($pipRc -ne 0) {
        Write-AitError "modal cli" "pip module install failed" (Get-AitErrorReason -Output $pipOutput -ExitCode $pipRc)
    } elseif (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = Get-ModalVersion
        LogOk "Modal CLI installed ($modalVersion)"
        Write-Summary "OK" "modal cli" "$modalVersion"
    } else {
        Write-AitError "modal cli" "installed but not on PATH" "modal not found after python -m pip install --user"
    }
} else {
    Write-AitError "modal cli" "no package installer" "neither uv nor pip is on PATH"
}

# Only suggest auth if modal is installed, this run had no error, and modal is not yet
# authenticated
# Get-Command exempt: command-existence check with if/else fallback
if ((Get-Command modal -ErrorAction SilentlyContinue) -and $errors -eq 0) {
    $modalToml = Join-Path $HOME ".modal.toml"
    if (-not (Test-Path $modalToml)) {
        Write-AitAction "modal cli" "not authenticated -- run: modal setup (browser flow)" "modal setup -- authenticate modal (browser flow)"
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
