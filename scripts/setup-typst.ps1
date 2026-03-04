# setup-typst.ps1 -- Installs/updates Typst (document typesetting / PDF compiler) on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred). Removes non-preferred installs (cargo, npm).
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-typst"

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

# --- Cleanup non-preferred installs ---
# Cargo typst-cli: different binary path, may shadow winget install
$cargoCmd = Get-Command cargo -ErrorAction SilentlyContinue
# Get-Command exempt: command-existence check with if/else fallback
if ($cargoCmd) {
    Log "Checking for cargo typst-cli..."
    # Cleanup: cargo stderr may contain "not installed" msg; non-blocking, winget install follows
    & cargo uninstall typst-cli 2>$null
}
# npm typst: third-party wrapper, not official
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
# Get-Command exempt: command-existence check with if/else fallback
if ($npmCmd) {
    Log "Checking for npm typst..."
    # Cleanup: npm stderr may contain "not installed" msg; non-blocking, winget install follows
    & npm uninstall -g typst 2>$null
}

# --- Install/update ---
$typstCmd = Get-Command typst -ErrorAction SilentlyContinue
# Get-Command exempt: command-existence check with if/else fallback
if ($typstCmd) {
    Log "Typst found -- upgrading via winget..."
    $wingetOutput = winget upgrade --id Typst.Typst --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$') { Log $l }
    }
    if ($wingetOutput -match 'No available upgrade|No newer package versions') {
        LogOk "Typst already up to date"
    } elseif ($LASTEXITCODE -ne 0) {
        LogError "winget upgrade typst failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "typst" "winget upgrade failed (exit $LASTEXITCODE)"
    }
    Refresh-Path
    # Suppress stderr: typst may emit warnings on some configs; result checked immediately
    $version = (typst --version 2>$null)
    if ($version) {
        LogOk $version
        Write-Summary "OK" "typst" "$version"
    } else {
        LogError "typst --version failed after upgrade"
        Write-Summary "ERROR" "typst" "version check failed after upgrade"
    }
} else {
    Log "Installing Typst via winget..."
    $wingetOutput = winget install --id Typst.Typst --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$') { Log $l }
    }
    if ($LASTEXITCODE -ne 0) {
        LogError "winget install typst failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "typst" "winget install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path
    $typstCmd = Get-Command typst -ErrorAction SilentlyContinue
    # Get-Command exempt: command-existence check with if/else fallback
    if ($typstCmd) {
        # Suppress stderr: typst may emit warnings on some configs; result used in log
        $version = (typst --version 2>$null)
        LogOk "Typst installed ($version)"
        Write-Summary "OK" "typst" "$version"
    } else {
        LogError "winget install completed but 'typst' not found in PATH"
        Write-Summary "ERROR" "typst" "install failed (not on PATH)"
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
