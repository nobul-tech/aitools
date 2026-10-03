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

# --- Cleanup non-preferred installs ---
# Only packages that are actually installed are removed; a failed removal is a
# warning (non-blocking -- the winget install below proceeds), with the output logged.
function Remove-NonPreferred([string]$Label, [scriptblock]$Command) {
    $out = & $Command 2>&1 | Out-String
    $rc = $LASTEXITCODE
    foreach ($l in $out.Split("`n")) { if ($l.Trim()) { LogDetail "${Label}: $($l.TrimEnd())" } }
    if ($rc -eq 0) {
        Log "Removed non-preferred install ($Label)"
    } else {
        LogWarn "$Label failed (exit $rc) -- see $logFile"
    }
}
# Cargo typst-cli: different binary path, may shadow winget install
$cargoCmd = Get-Command cargo -ErrorAction SilentlyContinue
# Get-Command exempt: command-existence check with if/else fallback
if ($cargoCmd) {
    $cargoList = & cargo install --list 2>&1 | Out-String
    $cargoListRc = $LASTEXITCODE
    if ($cargoListRc -ne 0) {
        LogDetail "cargo-install-list: $($cargoList.Trim())"
        LogWarn "cargo install --list failed (exit $cargoListRc) -- skipping cargo typst-cli cleanup"
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
    Log-WingetOutput $wingetOutput
    if ($wingetOutput -match 'No available upgrade|No newer package versions') {
        LogOk "Typst already up to date"
    } elseif ($upgradeRc -ne 0) {
        LogError "winget upgrade typst failed (exit $upgradeRc) -- see $logFile"
        Write-Summary "ERROR" "typst" "winget upgrade failed (exit $upgradeRc)"
    }
    Refresh-Path
    if ($errors -eq 0) {
        # Suppress stderr: typst may emit warnings on some configs; result checked immediately
        $version = (typst --version 2>$null)
        if ($version) {
            LogOk $version
            Write-Summary "OK" "typst" "$version"
        } else {
            LogError "typst --version failed after upgrade"
            Write-Summary "ERROR" "typst" "version check failed after upgrade"
        }
    }
} else {
    Log "Installing Typst via winget..."
    $wingetOutput = winget install --id Typst.Typst --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    Log-WingetOutput $wingetOutput
    if ($installRc -ne 0) {
        LogError "winget install typst failed (exit $installRc) -- see $logFile"
        Write-Summary "ERROR" "typst" "winget install failed (exit $installRc)"
    }
    Refresh-Path
    $typstCmd = Get-Command typst -ErrorAction SilentlyContinue
    # Get-Command exempt: command-existence check with if/else fallback
    if ($typstCmd) {
        # Suppress stderr: typst may emit warnings on some configs; result checked immediately
        $version = (typst --version 2>$null)
        if ($version) {
            LogOk "Typst installed ($version)"
            Write-Summary "OK" "typst" "$version"
        } else {
            LogError "typst --version failed after install"
            Write-Summary "ERROR" "typst" "version check failed after install"
        }
    } else {
        LogError "winget install completed but 'typst' not found in PATH"
        Write-Summary "ERROR" "typst" "install failed (not on PATH)"
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
