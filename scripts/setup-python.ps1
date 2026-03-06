# setup-python.ps1 -- Installs/updates Python on Windows via pymanager
# Safe to re-run -- detects existing install and upgrades as needed.
#
# Windows: Installs Python Install Manager (pymanager) via winget, then
# installs the Python runtime via `py install`. Removes Microsoft Store
# (MSIX) Python if detected (conflicts with pymanager).
# pip available as `python -m pip` (PEP 773 deprecates standalone pip).
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-python"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# Pymanager winget ID (version-agnostic -- auto-updates via winget)
$pymanagerWingetId = "Python.PythonInstallManager"

# Target Python runtime version (bump here for future upgrades)
$targetPyVersion = "3.14"

# Helper: refresh PATH from registry (picks up winget installs in same session)
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# --- Remove Microsoft Store (MSIX) Python if present ---
$msixPackages = Get-AppxPackage *PythonSoftwareFoundation* -ErrorAction SilentlyContinue
if ($msixPackages) {
    Log "Microsoft Store Python detected -- removing (conflicts with pymanager)..."
    foreach ($pkg in $msixPackages) {
        Log "Removing: $($pkg.PackageFullName)"
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            LogOk "Removed MSIX package: $($pkg.PackageFullName)"
        } catch {
            LogWarn "Could not remove MSIX package: $($pkg.PackageFullName) -- $_"
        }
    }
    Refresh-Path
} else {
    Log "No Microsoft Store Python found (OK)"
}

# Refresh PATH to pick up tools installed by prior steps or previous runs
Refresh-Path

# --- Detect legacy Python.Python.3.x winget install ---
$legacyOutput = winget list --id Python.Python --accept-source-agreements 2>&1 | Out-String
if ($legacyOutput -match 'Python\.Python\.3\.(\d+)') {
    $legacyMinor = $Matches[1]
    LogWarn "Legacy winget Python install detected (Python.Python.3.$legacyMinor)"
    LogWarn "pymanager will manage Python runtimes going forward"
    LogWarn "To uninstall legacy: winget uninstall Python.Python.3.$legacyMinor"
    Write-Summary "ACTION" "" "winget uninstall Python.Python.3.$legacyMinor -- remove legacy Python"
}

# --- Install/update pymanager ---
# Get-Command exempt: command-existence check with if/else fallback
$hasPymanager = (Get-Command pymanager -ErrorAction SilentlyContinue) -ne $null

if ($hasPymanager) {
    # Pymanager already installed -- upgrade via winget
    Log "pymanager found -- checking for updates via winget..."
    $wingetOutput = winget upgrade $pymanagerWingetId --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$') { Log $l }
    }
    if ($wingetOutput -match 'No available upgrade|No newer package versions') {
        LogOk "pymanager already up to date"
    } elseif ($wingetOutput -match 'No installed package') {
        Log "winget has no record of $pymanagerWingetId -- reinstalling..."
        $wingetOutput = winget install $pymanagerWingetId --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            LogError "winget install pymanager failed (exit code $LASTEXITCODE)"
            Write-Summary "ERROR" "python" "winget install pymanager failed"
        }
    } elseif ($LASTEXITCODE -ne 0) {
        LogError "winget upgrade pymanager failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "python" "winget upgrade pymanager failed"
    }
} else {
    # Pymanager not present (may have old py.exe launcher or nothing)
    Log "Installing pymanager via winget ($pymanagerWingetId)..."
    $wingetOutput = winget install $pymanagerWingetId --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $wingetOutput.Trim().Split("`n") | ForEach-Object {
        $l = $_.TrimEnd()
        if ($l.Trim() -and $l.Trim() -notmatch '^[-\\|/]+$') { Log $l }
    }
    if ($wingetOutput -match 'already installed') {
        LogOk "pymanager already installed (winget)"
    } elseif ($LASTEXITCODE -ne 0) {
        LogError "winget install pymanager failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "python" "winget install pymanager failed"
    }
}

Refresh-Path

# --- Verify pymanager is available ---
# Get-Command exempt: command-existence check with if/else fallback
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
    LogError "pymanager installed but 'py' not found in PATH"
    Write-Summary "ERROR" "python" "pymanager not on PATH"
} else {
    # --- Install/update Python runtime ---
    $pyListOutput = py list 2>&1 | Out-String
    if ($pyListOutput -match $targetPyVersion) {
        Log "Python $targetPyVersion already installed -- checking for updates..."
        $pyUpdateOutput = py install --update $targetPyVersion 2>&1 | Out-String
        $pyUpdateOutput.Trim().Split("`n") | ForEach-Object {
            $l = $_.TrimEnd()
            if ($l.Trim()) { Log $l }
        }
        if ($LASTEXITCODE -ne 0) {
            LogWarn "py install --update returned non-zero (exit code $LASTEXITCODE)"
        }
    } else {
        Log "Installing Python $targetPyVersion via pymanager..."
        $pyInstallOutput = py install $targetPyVersion 2>&1 | Out-String
        $pyInstallOutput.Trim().Split("`n") | ForEach-Object {
            $l = $_.TrimEnd()
            if ($l.Trim()) { Log $l }
        }
        if ($LASTEXITCODE -ne 0) {
            LogError "py install $targetPyVersion failed (exit code $LASTEXITCODE)"
            Write-Summary "ERROR" "python" "runtime install failed"
        }
    }

    Refresh-Path

    # --- Verify python command works ---
    # Get-Command exempt: command-existence check with if/else fallback
    $pythonCheck = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCheck) {
        $pyVersion = python --version 2>$null
        if ($pyVersion) {
            LogOk "$pyVersion (via pymanager)"
            Log "Install path: $($pythonCheck.Source)"
            Write-Summary "OK" "python" "$pyVersion"

            # Warn if legacy install is shadowing pymanager
            if ($pyVersion -notmatch $targetPyVersion) {
                LogWarn "python --version reports $pyVersion (expected $targetPyVersion)"
                LogWarn "Legacy Python install may be shadowing pymanager on PATH"
            }
        } else {
            LogError "python found on PATH but --version failed"
            Write-Summary "ERROR" "python" "version check failed"
        }
    } else {
        LogError "'python' command not found after pymanager install"
        LogWarn "Check 'Manage app execution aliases' in Windows Settings"
        Write-Summary "ERROR" "python" "python not on PATH"

        # Check if pymanager bin dir is in persistent PATH
        $pymanagerBin = Join-Path $env:LOCALAPPDATA "Python\bin"
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$pymanagerBin*") {
            LogWarn "Add $pymanagerBin to PATH for python/pip aliases"
            Write-Summary "ACTION" "" "Add $pymanagerBin to PATH -- python alias"
        }
    }

    # --- Verify pip ---
    # Get-Command exempt: command-existence check with if/else fallback
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        $pipVersion = pip --version 2>$null
        if ($pipVersion) {
            LogOk "pip available: $pipVersion"
        }
    } else {
        # PEP 773: standalone pip deprecated; python -m pip is the future
        $pipModVersion = python -m pip --version 2>$null
        if ($pipModVersion) {
            LogOk "pip available (module): $pipModVersion"
        } else {
            LogWarn "pip not found -- try: python -m ensurepip"
        }
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
