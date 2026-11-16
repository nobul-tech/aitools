# setup-go.ps1 -- Installs/updates Go on Windows via winget
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Uses winget (preferred). Warns for Chocolatey/Scoop installs.
# macOS/Linux: Uses Homebrew -- see setup-go.sh.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
        Write-AitWarn "go" "installed via Chocolatey -- removing it, then installing with winget"
        $chocoOutput = choco uninstall golang -y 2>&1 | Out-String
        $chocoRc = $LASTEXITCODE
        if ($chocoRc -ne 0) {
            # Get-AitErrorReason logs the output as detail lines
            Write-AitWarn "go" "choco uninstall golang failed (may need admin): $(Get-AitErrorReason -Output $chocoOutput -ExitCode $chocoRc) -- proceeding with winget install"
        } else {
            foreach ($l in $chocoOutput.Split("`n")) { if ($l.Trim()) { LogDetail "choco-uninstall-golang: $($l.TrimEnd())" } }
            LogOk "Chocolatey Go removed"
            $provenance = "none"
        }
        Refresh-Path
    }
    "scoop" {
        # One warning, no ACTION: a Scoop user may keep Scoop on purpose
        Write-AitWarn "go" "managed by Scoop, not winget -- to switch: scoop uninstall go, then re-run aitools install"
    }
}

# --- Install/update via winget ---
Refresh-Path

if ($provenance -eq "winget") {
    # Upgrade existing winget Go
    Log "Go already installed via winget -- checking for updates..."
    $wingetOutput = winget upgrade $goWingetId --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $upgradeRc = $LASTEXITCODE
    if ($wingetOutput -match 'No available upgrade|No newer package versions') {
        Log-WingetOutput $wingetOutput
        LogOk "Go already up to date"
    } elseif ($upgradeRc -ne 0) {
        # The existing Go still works: a warning, not an error (Standard 3); the
        # version check below still writes its OK record.
        # Get-AitErrorReason logs the output as detail lines.
        Write-AitWarn "go" "winget upgrade failed: $(Get-AitErrorReason -Output $wingetOutput -ExitCode $upgradeRc)"
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path

    # A failed upgrade is a warning (above), so the version check runs after it too.
    if ($errors -eq 0) {
        # Get-Command exempt: command-existence check with if/else fallback
        $goCheck = Get-Command go -ErrorAction SilentlyContinue
        if ($goCheck) {
            # Suppress stderr: result checked immediately (empty -> ERROR below)
            $goVersion = go version 2>$null
            if ($goVersion) {
                LogOk "$goVersion"
                Write-Summary "OK" "go" "$goVersion"
            } else {
                Write-AitError "go" "version check failed" "'go version' printed nothing"
            }
        } else {
            Write-AitError "go" "not on PATH after upgrade" "go not found on PATH after winget upgrade"
        }
    }
} elseif ($provenance -eq "scoop") {
    # Scoop users manage their own Go -- just verify and report (its warning is above)
    # Get-Command exempt: command-existence check with if/else fallback
    $goCheck = Get-Command go -ErrorAction SilentlyContinue
    if ($goCheck) {
        # Suppress stderr: result checked immediately (empty -> warning below)
        $goVersion = go version 2>$null
        if ($goVersion) {
            LogOk "Go via Scoop: $goVersion"
            Write-Summary "OK" "go" "$goVersion"
        } else {
            Write-AitWarn "go" "Scoop Go: 'go version' printed nothing"
        }
    } else {
        # Not on PATH is an error, not a warning (Standard 4)
        Write-AitError "go" "not on PATH" "Go is reported as installed by Scoop, but 'go' is not on PATH"
    }
} else {
    # Fresh install via winget
    Log "Installing Go via winget ($goWingetId)..."
    $wingetOutput = winget install $goWingetId --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    if ($wingetOutput -match 'already installed') {
        Log-WingetOutput $wingetOutput
        LogOk "Go already installed (winget)"
    } elseif ($installRc -ne 0) {
        # Get-AitErrorReason logs the output as detail lines
        Write-AitError "go" "winget install failed" (Get-AitErrorReason -Output $wingetOutput -ExitCode $installRc)
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path

    # After a failed install its ERROR row stands alone (no second row after it).
    if ($errors -eq 0) {
        # Get-Command exempt: command-existence check with if/else fallback
        $goCheck = Get-Command go -ErrorAction SilentlyContinue
        if ($goCheck) {
            # Suppress stderr: result checked immediately (empty -> ERROR below)
            $goVersion = go version 2>$null
            if ($goVersion) {
                LogOk "Go installed ($goVersion)"
                Write-Summary "OK" "go" "$goVersion"
            } else {
                Write-AitError "go" "version check failed" "'go version' printed nothing"
            }
        } else {
            Write-AitError "go" "installed but not on PATH" "go not found on PATH after winget install"
        }
    }
}

# --- Ensure GOPATH\bin is on PATH ---
# Fires once per machine: Ensure-GopathBinOnPath returns $true once the directory is there
$pathResult = Ensure-GopathBinOnPath
if (-not $pathResult) {
    $gopathBin = if ($env:GOPATH) { Join-Path $env:GOPATH "bin" } else { Join-Path $env:USERPROFILE "go\bin" }
    Write-AitAction "go" "$gopathBin was added to the persistent user PATH -- restart the terminal to use it" "Restart terminal -- GOPATH\bin added to PATH"
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
