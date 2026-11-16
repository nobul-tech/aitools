# setup-pandoc.ps1 -- Installs/updates Pandoc on Windows
# Safe to re-run -- detects existing install and upgrades or migrates as needed.
#
# Windows: Uses winget (preferred). Detects and warns about non-preferred installs
#          (Chocolatey, Conda, manual installer).
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-pandoc"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Install/update ---
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command pandoc -ErrorAction SilentlyContinue) {
    $pandocVersion = (pandoc --version | Select-Object -First 1)
    $pandocPath = (Get-Command pandoc).Source
    LogOk "Pandoc already installed ($pandocVersion)"
    Log "Install path: $pandocPath"

    # Check if installed via winget by attempting upgrade
    Log "Checking for updates via winget..."
    $upgradeResult = winget upgrade --exact --id JohnMacFarlane.Pandoc --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $upgradeRc = $LASTEXITCODE
    if ($upgradeResult -match "No available upgrade found|No newer package versions") {
        Log-WingetOutput $upgradeResult
        LogOk "Pandoc already up to date"
        Write-Summary "OK" "pandoc" "$pandocVersion"
    } elseif ($upgradeRc -eq 0) {
        Log-WingetOutput $upgradeResult
        Refresh-Path
        $pandocVersion = (pandoc --version | Select-Object -First 1)
        LogOk "Pandoc updated ($pandocVersion)"
        Write-Summary "OK" "pandoc" "$pandocVersion"
    } else {
        # The installed pandoc still works: a warning plus its OK status
        # (script-standards-detail Standard 3); Get-AitErrorReason logs the output
        Write-AitWarn "pandoc" "winget upgrade failed (pandoc may not be a winget install): $(Get-AitErrorReason -Output $upgradeResult -ExitCode $upgradeRc)"
        # Detect non-preferred installs
        # Get-Command exempt: command-existence check with if/else fallback
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            $chocoList = choco list pandoc 2>&1 | Out-String
            $chocoRc = $LASTEXITCODE
            if ($chocoRc -ne 0) {
                Write-AitWarn "pandoc" "choco list pandoc failed, Chocolatey install not checked: $(Get-AitErrorReason -Output $chocoList -ExitCode $chocoRc)"
            } elseif ($chocoList -match '(?m)^pandoc ') {
                Write-AitWarn "pandoc" "installed via Chocolatey -- prefer winget for managed installs"
            }
        }
        Write-Summary "OK" "pandoc" "$pandocVersion"
    }
} else {
    Log "Installing Pandoc via winget..."
    $wingetOutput = winget install --source winget --exact --id JohnMacFarlane.Pandoc --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    if ($installRc -ne 0) {
        # Get-AitErrorReason logs the output as detail lines
        Write-AitError "pandoc" "winget install failed" (Get-AitErrorReason -Output $wingetOutput -ExitCode $installRc)
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path

    # Get-Command exempt: command-existence check with if/else fallback
    if (Get-Command pandoc -ErrorAction SilentlyContinue) {
        $pandocVersion = (pandoc --version | Select-Object -First 1)
        $pandocPath = (Get-Command pandoc).Source
        LogOk "Pandoc installed ($pandocVersion)"
        Log "Install path: $pandocPath"
        Write-Summary "OK" "pandoc" "$pandocVersion"

        # Verify the install directory is in persistent PATH
        $pandocDir = Split-Path $pandocPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$pandocDir*") {
            # Standard 4: one error, plus the remedy as an ACTION
            Write-AitError "pandoc" "installed but not on PATH" "$pandocDir is not in the persistent PATH"
            Write-Summary "ACTION" "" "Add $pandocDir to PATH -- pandoc not accessible"
        }
    } elseif ($installRc -ne 0) {
        # One failed install, one red line: the winget error above is the cause
        Log "pandoc not found after the failed winget install"
    } else {
        Write-AitError "pandoc" "installed but not on PATH" "winget exited 0 but Get-Command pandoc found nothing"
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
