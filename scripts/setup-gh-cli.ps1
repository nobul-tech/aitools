# setup-gh-cli.ps1 -- Installs/updates GitHub CLI (gh) on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred).
#
# Auth (gh auth login) is interactive -- handled by aitools-install Step 2, not here.
#
# See reference/tool-registry.md for install source details.

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "aitools"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-gh-cli"
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
function Write-Summary($cat, $tool, $detail) {
    if ($env:AITOOLS_SUMMARY_FILE) { Add-Content -Path $env:AITOOLS_SUMMARY_FILE -Value "${cat}|${tool}|${detail}" }
}

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# Helper: refresh PATH from registry (picks up winget installs in same session)
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# --- Install/update ---
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghVersion = (gh --version | Select-Object -First 1)
    $ghPath = (Get-Command gh).Source
    LogOk "gh CLI already installed ($ghVersion)"
    Log "Install path: $ghPath"

    Log "Checking for updates via winget..."
    $upgradeResult = winget upgrade --exact --id GitHub.cli --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    if ($upgradeResult -match "No available upgrade found|No newer package versions") {
        LogOk "gh CLI already up to date"
        Write-Summary "OK" "gh cli" "$ghVersion"
    } elseif ($LASTEXITCODE -eq 0) {
        Refresh-Path
        $ghVersion = (gh --version | Select-Object -First 1)
        LogOk "gh CLI updated ($ghVersion)"
        Write-Summary "OK" "gh cli" "$ghVersion"
    } else {
        LogWarn "winget upgrade returned non-zero (exit $LASTEXITCODE) -- gh CLI may be installed via another method"
        Write-Summary "WARN" "gh cli" "$ghVersion (upgrade check failed)"
    }
} else {
    Log "Installing gh CLI via winget..."
    $wingetOutput = winget install --source winget --exact --id GitHub.cli --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object { Log $_.TrimEnd() }
    if ($LASTEXITCODE -ne 0) {
        LogError "winget install failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "gh cli" "winget install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $ghVersion = (gh --version | Select-Object -First 1)
        $ghPath = (Get-Command gh).Source
        LogOk "gh CLI installed ($ghVersion)"
        Log "Install path: $ghPath"
        Write-Summary "OK" "gh cli" "$ghVersion"

        # Verify the install directory is in persistent PATH
        $ghDir = Split-Path $ghPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$ghDir*") {
            LogError "gh CLI install dir not in persistent PATH: $ghDir"
            Write-Summary "ERROR" "gh cli" "installed but not on PATH"
            LogWarn "Add $ghDir to PATH -- tool not accessible to Claude Code"
            Write-Summary "ACTION" "" "Add $ghDir to PATH -- gh not accessible"
        }
    } else {
        LogError "gh CLI install failed"
        Write-Summary "ERROR" "gh cli" "install failed"
    }
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
