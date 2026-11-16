# setup-gh-cli.ps1 -- Installs/updates GitHub CLI (gh) on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred).
#
# Auth (gh auth login) is interactive -- handled by aitools-install Step 2, not here.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
    if ($upgradeResult -match "No available upgrade found|No newer package versions") {
        Log-WingetOutput $upgradeResult
        LogOk "gh CLI already up to date"
        Write-Summary "OK" "gh cli" "$ghVersion"
    } elseif ($upgradeRc -eq 0) {
        Log-WingetOutput $upgradeResult
        Refresh-Path
        $ghVersion = (gh --version | Select-Object -First 1)
        LogOk "gh CLI updated ($ghVersion)"
        Write-Summary "OK" "gh cli" "$ghVersion"
    } else {
        # The installed gh still works: a warning, not an error (Standard 3).
        # Get-AitErrorReason logs the output as detail lines.
        Write-AitWarn "gh cli" "winget upgrade failed: $(Get-AitErrorReason -Output $upgradeResult -ExitCode $upgradeRc) -- gh may come from another installer"
        Write-Summary "OK" "gh cli" "$ghVersion"
    }
} else {
    Log "Installing gh CLI via winget..."
    $wingetOutput = winget install --source winget --exact --id GitHub.cli --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    if ($installRc -eq 0) { Log-WingetOutput $wingetOutput }
    Refresh-Path

    # Get-Command exempt: command-existence check with if/else fallback
    if ($installRc -ne 0) {
        Write-AitError "gh cli" "winget install failed" (Get-AitErrorReason -Output $wingetOutput -ExitCode $installRc)
    } elseif (Get-Command gh -ErrorAction SilentlyContinue) {
        $ghVersion = (gh --version | Select-Object -First 1)
        $ghPath = (Get-Command gh).Source
        LogOk "gh CLI installed ($ghVersion)"
        Log "Install path: $ghPath"

        # Verify the install directory is in persistent PATH
        $ghDir = Split-Path $ghPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$ghDir*") {
            # Standard 4: one error, plus the remedy as an ACTION
            Write-AitError "gh cli" "installed but not on PATH" "$ghDir is not in the persistent PATH"
            Write-Summary "ACTION" "" "Add $ghDir to PATH -- gh not accessible"
        } else {
            Write-Summary "OK" "gh cli" "$ghVersion"
        }
    } else {
        Write-AitError "gh cli" "installed but not on PATH" "gh not found after winget install"
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
