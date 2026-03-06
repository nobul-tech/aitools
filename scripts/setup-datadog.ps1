# setup-datadog.ps1 -- Installs/updates Datadog CLI (pup) on Windows via cargo install
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses cargo install (Rust-based CLI; no winget/chocolatey package available).
#          Requires Rust/cargo to be installed first (Step 12 in aitools-install).
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

# --- Check cargo is available ---
# Get-Command exempt: command-existence check with explicit fallback
$cargoCheck = Get-Command cargo -ErrorAction SilentlyContinue
if (-not $cargoCheck) {
    LogError "Rust (cargo) is not installed -- required for Datadog CLI on Windows. Run setup-rust.ps1 first."
    Write-Summary "ERROR" "datadog cli" "Rust not installed (prerequisite)"
} else {
    # --- Detect existing install ---
    # Get-Command exempt: command-existence check with explicit fallback
    $pupCheck = Get-Command pup -ErrorAction SilentlyContinue

    if ($pupCheck) {
        $pupVersion = pup version 2>$null
        if ($pupVersion) {
            Log "Pup already installed ($pupVersion) -- upgrading via cargo install..."
        } else {
            Log "Pup found but version check failed -- upgrading via cargo install..."
        }
        $cargoOutput = cargo install --git https://github.com/datadog-labs/pup 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $cargoOutput.Trim().Split("`n") | ForEach-Object { $l = $_.TrimEnd(); if ($l.Trim()) { Log $l } }
            LogError "cargo install pup failed (exit code $LASTEXITCODE)"
            Write-Summary "ERROR" "datadog cli" "cargo install failed"
        } else {
            Refresh-Path
            $pupVersion = pup version 2>$null
            if ($pupVersion) {
                LogOk "Pup upgraded ($pupVersion)"
                Write-Summary "OK" "datadog cli" "$pupVersion"
            } else {
                LogError "cargo install completed but 'pup version' failed"
                Write-Summary "ERROR" "datadog cli" "version check failed after upgrade"
            }
        }
    } else {
        # Fresh install
        Log "Installing Pup via cargo install..."
        $cargoOutput = cargo install --git https://github.com/datadog-labs/pup 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $cargoOutput.Trim().Split("`n") | ForEach-Object { $l = $_.TrimEnd(); if ($l.Trim()) { Log $l } }
            LogError "cargo install pup failed (exit code $LASTEXITCODE)"
            Write-Summary "ERROR" "datadog cli" "cargo install failed"
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
            LogError "cargo install completed but 'pup' not found in PATH"
            Write-Summary "ERROR" "datadog cli" "installed but not on PATH"
        }
    }
}

# --- Auth status check ---
# pup auth status exits 0 regardless; check output content for auth state
# Get-Command exempt: command-existence check with explicit fallback
if ((Get-Command pup -ErrorAction SilentlyContinue) -and $errors -eq 0) {
    $authOutput = pup auth status 2>&1 | Out-String
    if ($authOutput -match 'Not authenticated|"authenticated":\s*false') {
        LogWarn "Not authenticated: run 'pup auth login' (one-time OAuth)"
        Write-Summary "WARN" "datadog cli" "not authenticated"
        Write-Summary "ACTION" "" "pup auth login -- authenticate Datadog CLI"
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
