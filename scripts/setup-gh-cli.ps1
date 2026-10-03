# setup-gh-cli.ps1 -- Installs/updates GitHub CLI (gh) on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred).
#
# Auth (gh auth login) is interactive -- handled by aitools-install Step 2, not here.
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-gh-cli"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Install/update ---
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $ghVersion = (gh --version | Select-Object -First 1)
    $ghPath = (Get-Command gh).Source
    LogOk "gh CLI already installed ($ghVersion)"
    Log "Install path: $ghPath"

    Log "Checking for updates via winget..."
    $upgradeResult = winget upgrade --exact --id GitHub.cli --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $upgradeRc = $LASTEXITCODE
    Log-WingetOutput $upgradeResult
    if ($upgradeResult -match "No available upgrade found|No newer package versions") {
        LogOk "gh CLI already up to date"
        Write-Summary "OK" "gh cli" "$ghVersion"
    } elseif ($upgradeRc -eq 0) {
        Refresh-Path
        $ghVersion = (gh --version | Select-Object -First 1)
        LogOk "gh CLI updated ($ghVersion)"
        Write-Summary "OK" "gh cli" "$ghVersion"
    } else {
        LogWarn "winget upgrade returned non-zero (exit $upgradeRc) -- gh CLI may be installed via another method. See $logFile"
        Write-Summary "WARN" "gh cli" "$ghVersion (upgrade check failed, exit $upgradeRc)"
    }
} else {
    Log "Installing gh CLI via winget..."
    $wingetOutput = winget install --source winget --exact --id GitHub.cli --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    Log-WingetOutput $wingetOutput
    Refresh-Path

    # Get-Command exempt: command-existence check with if/else fallback
    if ($installRc -ne 0) {
        LogError "winget install gh failed (exit $installRc) -- see $logFile"
        Write-Summary "ERROR" "gh cli" "winget install failed (exit $installRc)"
    } elseif (Get-Command gh -ErrorAction SilentlyContinue) {
        $ghVersion = (gh --version | Select-Object -First 1)
        $ghPath = (Get-Command gh).Source
        LogOk "gh CLI installed ($ghVersion)"
        Log "Install path: $ghPath"

        # Verify the install directory is in persistent PATH
        $ghDir = Split-Path $ghPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$ghDir*") {
            LogError "gh CLI install dir not in persistent PATH: $ghDir"
            Write-Summary "ERROR" "gh cli" "installed but not on PATH"
            LogWarn "Add $ghDir to PATH -- tool not accessible to Claude Code"
            Write-Summary "ACTION" "" "Add $ghDir to PATH -- gh not accessible"
        } else {
            Write-Summary "OK" "gh cli" "$ghVersion"
        }
    } else {
        LogError "winget install completed but 'gh' not found in PATH"
        Write-Summary "ERROR" "gh cli" "installed but not on PATH"
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
