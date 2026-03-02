# setup-modal.ps1 -- Installs/updates Modal CLI on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses pip (pip install modal). Requires Python 3.10+.
#
# Authentication (modal setup) is interactive and must be run separately
# after install -- not automated by this script.
#
# See reference/tool-registry.md for install source details.

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "aitools"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-modal"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
$errors = 0
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg"; $script:errors++ }
function LogWarn($msg)  { Log "WARN: $msg" }
function Write-Summary($cat, $msg) {
    if ($env:AITOOLS_SUMMARY_FILE) { Add-Content -Path $env:AITOOLS_SUMMARY_FILE -Value "${cat}|${msg}" }
}

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Python/pip check ---
$pipCmd = $null
if (Get-Command pip -ErrorAction SilentlyContinue) {
    $pipCmd = "pip"
} elseif (Get-Command pip3 -ErrorAction SilentlyContinue) {
    $pipCmd = "pip3"
} else {
    LogError "pip not found. Install Python 3.10+ first: https://python.org"
    exit 1
}

# Verify Python 3.10+
$pythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCmd = "python"
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonCmd = "python3"
}

if ($pythonCmd) {
    $pyVersionStr = & $pythonCmd -c "import sys; print(str(sys.version_info.major) + '.' + str(sys.version_info.minor))" 2>$null
    if ($pyVersionStr -match '^(\d+)\.(\d+)') {
        $pyMajor = [int]$Matches[1]
        $pyMinor = [int]$Matches[2]
        if ($pyMajor -lt 3 -or ($pyMajor -eq 3 -and $pyMinor -lt 10)) {
            LogError "Python 3.10+ required. Found Python $pyVersionStr"
            exit 1
        }
        Log "Python $pyVersionStr found ($pythonCmd)"
    }
}

# --- Install/update ---
if (Get-Command modal -ErrorAction SilentlyContinue) {
    $modalVersion = & modal --version 2>$null
    if (-not $modalVersion) { $modalVersion = "version unknown" }
    LogOk "Modal CLI already installed ($modalVersion)"
    Log "Upgrading via $pipCmd..."
    & $pipCmd install --upgrade modal
    if (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = & modal --version 2>$null
        if (-not $modalVersion) { $modalVersion = "version unknown" }
        LogOk "Modal CLI upgraded ($modalVersion)"
        Write-Summary "OK" "modal CLI    $modalVersion"
    } else {
        LogError "$pipCmd upgrade completed but 'modal' not found in PATH"
    }
} else {
    Log "Installing Modal CLI via $pipCmd..."
    & $pipCmd install modal
    if (Get-Command modal -ErrorAction SilentlyContinue) {
        $modalVersion = & modal --version 2>$null
        if (-not $modalVersion) { $modalVersion = "version unknown" }
        $modalPath = (Get-Command modal).Source
        LogOk "Modal CLI installed ($modalVersion)"
        Log "Install path: $modalPath"
        Write-Summary "OK" "modal CLI    $modalVersion"

        # Verify the install directory is in persistent PATH
        $modalDir = Split-Path $modalPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$modalDir*") {
            LogWarn "Modal install dir not in persistent PATH: $modalDir"
            LogWarn "Claude Code may not find 'modal'. Add this directory to your User PATH."
        }
    } else {
        LogWarn "Modal installed but 'modal' not found in PATH"
        LogWarn "You may need to add Python's Scripts directory to PATH."
        if ($pythonCmd) { LogWarn "Try: $pythonCmd -m modal --version" }
    }
}

LogWarn "Authentication required: run 'modal setup' to authenticate (browser flow)"
Write-Summary "ACTION" "modal setup -- authenticate modal (browser flow)"

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
