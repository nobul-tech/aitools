# setup-uv.ps1 -- Installs/updates uv (fast Python package installer) on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred).
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-uv"

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

# Refresh PATH to pick up tools installed by prior steps or previous runs
Refresh-Path

# --- Install/update ---
# Get-Command exempt: command-existence check with if/else fallback
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($uvCmd) {
    Log "uv found -- upgrading via winget..."
    $wingetOutput = winget upgrade --id=astral-sh.uv --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$' -and $l -notmatch '\d+(\.\d+)?\s*(KB|MB|GB)\s*/\s*\d+') { Log $l }
    }
    if ($wingetOutput -match 'No available upgrade|No newer package versions|No installed package') {
        LogOk "uv already up to date"
    } elseif ($LASTEXITCODE -ne 0) {
        LogError "winget upgrade uv failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "uv" "winget upgrade failed (exit $LASTEXITCODE)"
    }
    Refresh-Path
    if ($errors -eq 0) {
        $version = (uv --version 2>$null)
        if ($version) {
            LogOk $version
            Write-Summary "OK" "uv" "$version"
        } else {
            LogError "uv --version failed after upgrade"
            Write-Summary "ERROR" "uv" "version check failed after upgrade"
        }
    }
} else {
    Log "Installing uv via winget..."
    $wingetOutput = winget install --id=astral-sh.uv -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$' -and $l -notmatch '\d+(\.\d+)?\s*(KB|MB|GB)\s*/\s*\d+') { Log $l }
    }
    if ($wingetOutput -match 'already installed' -and $wingetOutput -match 'No available upgrade|No newer package versions') {
        LogOk "uv already up to date (winget)"
    } elseif ($LASTEXITCODE -ne 0) {
        LogError "winget install uv failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "uv" "winget install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path
    # Get-Command exempt: command-existence check with if/else fallback
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($uvCmd) {
        $version = (uv --version 2>$null)
        $uvPath = $uvCmd.Source
        LogOk "uv installed ($version)"
        Log "Install path: $uvPath"
        Write-Summary "OK" "uv" "$version"

        # Verify the install directory is in persistent PATH
        $uvDir = Split-Path $uvPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$uvDir*") {
            LogError "uv install dir not in persistent PATH: $uvDir"
            Write-Summary "ERROR" "uv" "installed but not on PATH"
            LogWarn "Add $uvDir to PATH -- tool not accessible to Claude Code"
            Write-Summary "ACTION" "" "Add $uvDir to PATH -- uv not accessible"
        }
    } else {
        LogError "winget install completed but 'uv' not found in PATH"
        Write-Summary "ERROR" "uv" "installed but not on PATH"
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
