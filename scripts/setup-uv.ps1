# setup-uv.ps1 -- Installs/updates uv (fast Python package installer) on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred).
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-uv"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# Refresh PATH to pick up tools installed by prior steps or previous runs
Refresh-Path

# --- Install/update ---
# Get-Command exempt: command-existence check with if/else fallback
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($uvCmd) {
    Log "uv found -- upgrading via winget..."
    $wingetOutput = winget upgrade --id=astral-sh.uv --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $upgradeRc = $LASTEXITCODE
    if ($wingetOutput -match 'No available upgrade|No newer package versions|No installed package') {
        Log-WingetOutput $wingetOutput
        LogOk "uv already up to date"
    } elseif ($upgradeRc -ne 0) {
        # The installed uv still works: a warning, not an error (Standard 3); the
        # $errors gate below still writes the OK record. Get-AitErrorReason logs the
        # output as detail lines.
        Write-AitWarn "uv" "winget upgrade failed: $(Get-AitErrorReason -Output $wingetOutput -ExitCode $upgradeRc)"
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path
    if ($errors -eq 0) {
        # stderr is captured with stdout for the error reason; the version is the
        # line that starts with "uv "
        $verOut = uv --version 2>&1 | Out-String
        $verRc = $LASTEXITCODE
        $version = ($verOut -split "`r?`n" | Where-Object { $_ -match '^uv ' } | Select-Object -First 1)
        if ($verRc -eq 0 -and $version) {
            LogOk $version
            Write-Summary "OK" "uv" "$version"
        } else {
            Write-AitError "uv" "version check failed after upgrade" (Get-AitErrorReason -Output $verOut -ExitCode $verRc)
        }
    }
} else {
    Log "Installing uv via winget..."
    $wingetOutput = winget install --id=astral-sh.uv -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    $installFailed = $false
    if ($wingetOutput -match 'already installed' -and $wingetOutput -match 'No available upgrade|No newer package versions') {
        Log-WingetOutput $wingetOutput
        LogOk "uv already up to date (winget)"
    } elseif ($installRc -ne 0) {
        $installFailed = $true
        # Get-AitErrorReason logs the output as detail lines
        Write-AitError "uv" "winget install failed" (Get-AitErrorReason -Output $wingetOutput -ExitCode $installRc)
    } else {
        Log-WingetOutput $wingetOutput
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
            Write-AitError "uv" "installed but not on PATH" "$uvDir is not in the persistent PATH"
            Write-Summary "ACTION" "" "Add $uvDir to PATH -- uv not accessible"
        }
    } elseif ($installFailed) {
        # One failure, one red line: the install error above is the cause
        Log "uv not found after the failed winget install"
    } elseif ($installRc -eq 0) {
        Write-AitError "uv" "installed but not on PATH" "winget exited 0 but Get-Command uv found nothing"
    } else {
        Write-AitError "uv" "installed but not on PATH" "winget reports uv already installed but Get-Command uv found nothing"
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
