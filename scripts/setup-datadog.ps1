# setup-datadog.ps1 -- Installs/updates Datadog CLI (pup) on Windows via go install
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses go install (no winget/chocolatey package available).
#          Requires Go to be installed first (Step 17 in aitools-install).
# macOS/Linux: Uses Homebrew -- see setup-datadog.sh.
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-datadog"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

$freshInstall = $false

# --- Check Go is available ---
# Get-Command exempt: command-existence check with explicit fallback
$goCheck = Get-Command go -ErrorAction SilentlyContinue
if (-not $goCheck) {
    LogError "Go is not installed -- required for Datadog CLI on Windows. Run setup-go.ps1 first."
    Write-Summary "ERROR" "datadog cli" "Go not installed (prerequisite)"
} else {
    # --- Detect existing install ---
    # Get-Command exempt: command-existence check with explicit fallback
    $pupCheck = Get-Command pup -ErrorAction SilentlyContinue

    if ($pupCheck) {
        $pupVersion = pup version 2>$null
        if ($pupVersion) {
            Log "Pup already installed ($pupVersion) -- upgrading via go install..."
        } else {
            Log "Pup found but version check failed -- upgrading via go install..."
        }
        $goOutput = go install github.com/DataDog/pup@latest 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            LogError "go install pup@latest failed (exit code $LASTEXITCODE)"
            Write-Summary "ERROR" "datadog cli" "go install failed"
        } else {
            Refresh-Path
            $pupVersion = pup version 2>$null
            if ($pupVersion) {
                LogOk "Pup upgraded ($pupVersion)"
                Write-Summary "OK" "datadog cli" "$pupVersion"
            } else {
                LogError "go install completed but 'pup version' failed"
                Write-Summary "ERROR" "datadog cli" "version check failed after upgrade"
            }
        }
    } else {
        # Fresh install
        $freshInstall = $true
        Log "Installing Pup via go install..."
        $goOutput = go install github.com/DataDog/pup@latest 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            LogError "go install pup@latest failed (exit code $LASTEXITCODE)"
            Write-Summary "ERROR" "datadog cli" "go install failed"
        }
        Refresh-Path

        # Get-Command exempt: command-existence check with explicit fallback
        $pupCheck = Get-Command pup -ErrorAction SilentlyContinue
        if ($pupCheck) {
            $pupVersion = pup version 2>$null
            if ($pupVersion) {
                LogOk "Pup installed ($pupVersion)"
                Write-Summary "OK" "datadog cli" "$pupVersion"
            } else {
                LogError "pup found but version check failed"
                Write-Summary "ERROR" "datadog cli" "version check failed"
            }
        } elseif ($errors -eq 0) {
            LogError "go install completed but 'pup' not found in PATH"
            Write-Summary "ERROR" "datadog cli" "installed but not on PATH"
        }
    }
}

# --- Auth reminder on fresh install ---
if ($freshInstall -and $errors -eq 0) {
    Write-Summary "ACTION" "" "Run: pup auth login (one-time OAuth)"
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
