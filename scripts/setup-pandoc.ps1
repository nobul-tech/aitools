# setup-pandoc.ps1 -- Installs/updates Pandoc on Windows
# Safe to re-run -- detects existing install and upgrades or migrates as needed.
#
# Windows: Uses winget (preferred). Detects and warns about non-preferred installs
#          (Chocolatey, Conda, manual installer).
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-pandoc"

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

# --- Install/update ---
if (Get-Command pandoc -ErrorAction SilentlyContinue) {
    $pandocVersion = (pandoc --version | Select-Object -First 1)
    $pandocPath = (Get-Command pandoc).Source
    LogOk "Pandoc already installed ($pandocVersion)"
    Log "Install path: $pandocPath"

    # Check if installed via winget by attempting upgrade
    Log "Checking for updates via winget..."
    $upgradeResult = winget upgrade --exact --id JohnMacFarlane.Pandoc --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    if ($upgradeResult -match "No available upgrade found|No newer package versions") {
        LogOk "Pandoc already up to date"
        Write-Summary "OK" "pandoc" "$pandocVersion"
    } elseif ($LASTEXITCODE -eq 0) {
        Refresh-Path
        $pandocVersion = (pandoc --version | Select-Object -First 1)
        LogOk "Pandoc updated ($pandocVersion)"
        Write-Summary "OK" "pandoc" "$pandocVersion"
    } else {
        LogWarn "winget upgrade returned non-zero (exit $LASTEXITCODE) -- pandoc may be installed via another method"
        # Detect non-preferred installs
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            $chocoList = choco list pandoc 2>$null | Out-String
            if ($chocoList -match "pandoc") {
                LogWarn "Pandoc appears to be installed via Chocolatey. Prefer winget for managed installs."
            }
        }
        Write-Summary "WARN" "pandoc" "$pandocVersion (upgrade check failed)"
    }
} else {
    Log "Installing Pandoc via winget..."
    $wingetOutput = winget install --source winget --exact --id JohnMacFarlane.Pandoc --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$') { Log $l }
    }
    if ($LASTEXITCODE -ne 0) {
        LogError "winget install failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "pandoc" "winget install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path

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
            LogError "Pandoc install dir not in persistent PATH: $pandocDir"
            Write-Summary "ERROR" "pandoc" "installed but not on PATH"
            LogWarn "Add $pandocDir to PATH -- tool not accessible to Claude Code"
            Write-Summary "ACTION" "" "Add $pandocDir to PATH -- pandoc not accessible"
        }
    } else {
        LogError "Pandoc install failed"
        Write-Summary "ERROR" "pandoc" "install failed"
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
