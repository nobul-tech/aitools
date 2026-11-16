# setup-typst.ps1 -- Installs/updates Typst (document typesetting / PDF compiler) on Windows
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred). Removes non-preferred installs (cargo, npm).
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-typst"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Cleanup non-preferred installs ---
# Only packages that are actually installed are removed; a failed removal is a
# warning (non-blocking -- the winget install below proceeds), with the output logged.
function Remove-NonPreferred([string]$Label, [scriptblock]$Command) {
    $out = & $Command 2>&1 | Out-String
    $rc = $LASTEXITCODE
    if ($rc -eq 0) {
        foreach ($l in $out.Split("`n")) { if ($l.Trim()) { LogDetail "${Label}: $($l.TrimEnd())" } }
        Log "Removed non-preferred install ($Label)"
    } else {
        # Get-AitErrorReason logs the output as detail lines (logging.md 8.2)
        Write-AitWarn "typst" "${Label} failed: $(Get-AitErrorReason -Output $out -ExitCode $rc)"
    }
}
# Cargo typst-cli: different binary path, may shadow winget install
$cargoCmd = Get-Command cargo -ErrorAction SilentlyContinue
# Get-Command exempt: command-existence check with if/else fallback
if ($cargoCmd) {
    $cargoList = & cargo install --list 2>&1 | Out-String
    $cargoListRc = $LASTEXITCODE
    if ($cargoListRc -ne 0) {
        Write-AitWarn "typst" "cargo install --list failed, cargo typst-cli cleanup skipped: $(Get-AitErrorReason -Output $cargoList -ExitCode $cargoListRc)"
    } elseif ($cargoList -match '(?m)^typst-cli ') {
        Remove-NonPreferred "cargo uninstall typst-cli" { cargo uninstall typst-cli }
    }
}
# npm typst: third-party wrapper, not official. `npm ls` exits non-zero when absent.
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
# Get-Command exempt: command-existence check with if/else fallback
if ($npmCmd) {
    $npmTypst = & npm ls -g --depth=0 typst 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        LogDetail "npm-ls-typst: $($npmTypst.Trim())"
        Remove-NonPreferred "npm uninstall -g typst" { npm uninstall -g typst }
    }
}

# --- Install/update ---
$typstCmd = Get-Command typst -ErrorAction SilentlyContinue
# Get-Command exempt: command-existence check with if/else fallback
if ($typstCmd) {
    Log "Typst found -- upgrading via winget..."
    $wingetOutput = winget upgrade --id Typst.Typst --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $upgradeRc = $LASTEXITCODE
    if ($wingetOutput -match 'No available upgrade|No newer package versions') {
        Log-WingetOutput $wingetOutput
        LogOk "Typst already up to date"
    } elseif ($upgradeRc -ne 0) {
        # The installed typst still works: a warning, not an error (Standard 3); the
        # $errors gate below still writes the OK record. Get-AitErrorReason logs the
        # output as detail lines.
        Write-AitWarn "typst" "winget upgrade failed: $(Get-AitErrorReason -Output $wingetOutput -ExitCode $upgradeRc)"
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path
    if ($errors -eq 0) {
        # stderr is captured with stdout for the error reason; the version is the
        # line that starts with "typst " (a warning typst prints is not taken for it)
        $verOut = typst --version 2>&1 | Out-String
        $verRc = $LASTEXITCODE
        $version = ($verOut -split "`r?`n" | Where-Object { $_ -match '^typst ' } | Select-Object -First 1)
        if ($verRc -eq 0 -and $version) {
            LogOk $version
            Write-Summary "OK" "typst" "$version"
        } else {
            Write-AitError "typst" "version check failed after upgrade" (Get-AitErrorReason -Output $verOut -ExitCode $verRc)
        }
    }
} else {
    Log "Installing Typst via winget..."
    $wingetOutput = winget install --id Typst.Typst --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    if ($installRc -ne 0) {
        # Get-AitErrorReason logs the output as detail lines
        Write-AitError "typst" "winget install failed" (Get-AitErrorReason -Output $wingetOutput -ExitCode $installRc)
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path
    $typstCmd = Get-Command typst -ErrorAction SilentlyContinue
    # Get-Command exempt: command-existence check with if/else fallback
    if ($typstCmd) {
        # As after the upgrade: stderr captured for the reason, the version line taken
        $verOut = typst --version 2>&1 | Out-String
        $verRc = $LASTEXITCODE
        $version = ($verOut -split "`r?`n" | Where-Object { $_ -match '^typst ' } | Select-Object -First 1)
        if ($verRc -eq 0 -and $version) {
            LogOk "Typst installed ($version)"
            Write-Summary "OK" "typst" "$version"
        } else {
            Write-AitError "typst" "version check failed after install" (Get-AitErrorReason -Output $verOut -ExitCode $verRc)
        }
    } elseif ($installRc -ne 0) {
        # One failure, one red line: the install error above is the cause
        Log "typst not found after the failed winget install"
    } else {
        Write-AitError "typst" "installed but not on PATH" "winget exited 0 but Get-Command typst found nothing"
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
