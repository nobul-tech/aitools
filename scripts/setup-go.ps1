# setup-go.ps1 -- Installs/updates Go on Windows via winget
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred). Warns for Chocolatey/Scoop installs.
# macOS/Linux: Uses Homebrew -- see setup-go.sh.
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-go"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

$goWingetId = "GoLang.Go"

# --- Detect provenance ---
$provenance = Get-GoProvenance
Log "Go install provenance: $provenance"

# --- Cleanup non-preferred installs ---
switch ($provenance) {
    "chocolatey" {
        LogWarn "Go installed via Chocolatey -- attempting removal..."
        $chocoOutput = choco uninstall golang -y 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            LogWarn "choco uninstall golang failed (may need admin) -- proceeding with winget install"
        } else {
            LogOk "Chocolatey Go removed"
            $provenance = "none"
        }
        Refresh-Path
    }
    "scoop" {
        LogWarn "Go installed via Scoop -- skipping cleanup (user-managed)"
        LogWarn "To switch to winget: scoop uninstall go, then re-run this script"
    }
}

# --- Install/update via winget ---
Refresh-Path

if ($provenance -eq "winget") {
    # Upgrade existing winget Go
    Log "Go already installed via winget -- checking for updates..."
    $wingetOutput = winget upgrade $goWingetId --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    Log-WingetOutput $wingetOutput
    if ($wingetOutput -match 'No available upgrade|No newer package versions') {
        LogOk "Go already up to date"
    } elseif ($LASTEXITCODE -ne 0) {
        LogError "winget upgrade Go failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "go" "winget upgrade failed"
    }
    Refresh-Path

    # Get-Command exempt: command-existence check with if/else fallback
    $goCheck = Get-Command go -ErrorAction SilentlyContinue
    if ($goCheck) {
        $goVersion = go version 2>$null
        if ($goVersion) {
            LogOk "$goVersion"
            Write-Summary "OK" "go" "$goVersion"
        } else {
            LogError "go found on PATH but 'go version' failed"
            Write-Summary "ERROR" "go" "version check failed"
        }
    } else {
        LogError "winget upgrade completed but 'go' not found in PATH"
        Write-Summary "ERROR" "go" "not on PATH after upgrade"
    }
} elseif ($provenance -eq "scoop") {
    # Scoop users manage their own Go -- just verify and report
    # Get-Command exempt: command-existence check with if/else fallback
    $goCheck = Get-Command go -ErrorAction SilentlyContinue
    if ($goCheck) {
        $goVersion = go version 2>$null
        if ($goVersion) {
            LogOk "Go via Scoop: $goVersion"
            Write-Summary "WARN" "go" "$goVersion (scoop -- not winget)"
        } else {
            LogWarn "Go found via Scoop but version check failed"
            Write-Summary "WARN" "go" "scoop install (version unknown)"
        }
    } else {
        LogWarn "Go reported as Scoop but 'go' not found in PATH"
        Write-Summary "WARN" "go" "scoop install not on PATH"
    }
} else {
    # Fresh install via winget
    Log "Installing Go via winget ($goWingetId)..."
    $wingetOutput = winget install $goWingetId --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    Log-WingetOutput $wingetOutput
    if ($wingetOutput -match 'already installed') {
        LogOk "Go already installed (winget)"
    } elseif ($LASTEXITCODE -ne 0) {
        LogError "winget install Go failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "go" "winget install failed"
    }
    Refresh-Path

    # Get-Command exempt: command-existence check with if/else fallback
    $goCheck = Get-Command go -ErrorAction SilentlyContinue
    if ($goCheck) {
        $goVersion = go version 2>$null
        if ($goVersion) {
            LogOk "Go installed ($goVersion)"
            Write-Summary "OK" "go" "$goVersion"
        } else {
            LogError "go found on PATH but 'go version' failed"
            Write-Summary "ERROR" "go" "version check failed"
        }
    } else {
        LogError "winget install completed but 'go' not found in PATH"
        Write-Summary "ERROR" "go" "installed but not on PATH"
    }
}

# --- Ensure GOPATH\bin is on PATH ---
$pathResult = Ensure-GopathBinOnPath
if (-not $pathResult) {
    $gopathBin = if ($env:GOPATH) { Join-Path $env:GOPATH "bin" } else { Join-Path $env:USERPROFILE "go\bin" }
    LogWarn "Added $gopathBin to persistent User PATH"
    Write-Summary "ACTION" "" "Restart terminal -- GOPATH\bin added to PATH"
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
