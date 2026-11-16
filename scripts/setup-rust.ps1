# setup-rust.ps1 — Installs/updates Rust toolchain (rustup + cargo) on Windows
# Safe to re-run — detects existing install and upgrades as needed.
#
# Windows: Uses winget to install rustup, which manages the Rust toolchain.
# Checks for MSVC Build Tools (required for linking) and warns if missing.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-rust"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Install/update ---
$cargoPath = Join-Path $env:USERPROFILE ".cargo\bin\cargo.exe"

if (Test-Path $cargoPath) {
    Log "rustup found -- updating toolchain..."
    $rustupExe = Join-Path $env:USERPROFILE ".cargo\bin\rustup.exe"
    $rustupOutput = & $rustupExe update 2>&1 | Out-String
    $updateRc = $LASTEXITCODE
    # The exit code decides (C-F2); the full output goes to the log as detail.
    if ($updateRc -ne 0) {
        # The installed toolchain still works: a warning, not an error (script-standards
        # Standard 3). Get-AitErrorReason logs the output as detail lines.
        Write-AitWarn "rust/cargo" "rustup update failed: $(Get-AitErrorReason -Output $rustupOutput -ExitCode $updateRc)"
        $cargoVersion = (& $cargoPath --version 2>&1)
        Write-Summary "OK" "rust/cargo" "$cargoVersion"
    } else {
        foreach ($l in $rustupOutput.Split("`n")) {
            if ($l.Trim()) { LogDetail "rustup-update: $($l.TrimEnd())" }
        }
        $cargoVersion = (& $cargoPath --version 2>&1)
        $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
        $rustcVersion = (& $rustcPath --version 2>&1)
        LogOk "cargo $cargoVersion"
        LogOk "rustc $rustcVersion"
        Write-Summary "OK" "rust/cargo" "$cargoVersion"
    }
} else {
    Log "Installing Rust toolchain via winget..."
    $wingetOutput = winget install -e --id Rustlang.Rustup --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $installRc = $LASTEXITCODE
    if ($installRc -ne 0) {
        # Get-AitErrorReason logs the output as detail lines
        Write-AitError "rust/cargo" "winget install failed" (Get-AitErrorReason -Output $wingetOutput -ExitCode $installRc)
    } else {
        Log-WingetOutput $wingetOutput
    }
    Refresh-Path

    if (Test-Path $cargoPath) {
        $cargoVersion = (& $cargoPath --version 2>&1)
        $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
        $rustcVersion = (& $rustcPath --version 2>&1)
        LogOk "Rust toolchain installed"
        LogOk "cargo $cargoVersion"
        LogOk "rustc $rustcVersion"
        Write-Summary "OK" "rust/cargo" "$cargoVersion"
    } elseif ($installRc -ne 0) {
        # One failure, one red line: the install error above is the cause
        Log "cargo not found after the failed winget install"
    } else {
        Write-AitError "rust/cargo" "cargo not found after install" "winget exited 0 but $cargoPath does not exist"
    }
}

# --- MSVC Build Tools check ---
# Rust on Windows requires MSVC Build Tools for linking.
# Check common install locations for VS Build Tools or Visual Studio with VC tools.
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasMSVC = $false
if (Test-Path $vsWhere) {
    # 2>$null: vswhere prints nothing on stdout when no install matches; stderr text
    # would make $vsInstalls non-empty and fake a match. Checked on the next line.
    $vsInstalls = & $vsWhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($vsInstalls) { $hasMSVC = $true }
}

if ($hasMSVC) {
    LogOk "MSVC Build Tools found"
} else {
    Write-AitAction "rust/cargo" "MSVC Build Tools not detected -- cargo build will fail without a C linker; install them" "winget install Microsoft.VisualStudio.2022.BuildTools, then add the workload Desktop Development with C++"
    Log "Install: winget install Microsoft.VisualStudio.2022.BuildTools"
    Log "  Then add workload: Desktop Development with C++"
}

# --- Build tool prerequisites (NASM, CMake, etc.) ---
# These are not needed by Rust itself, but by commonly used crates (aws-lc-sys, etc.)
# Get-Command exempt: command-existence check with explicit fallback
$nasmCheck = Get-Command nasm -ErrorAction SilentlyContinue
if (-not $nasmCheck) {
    # NASM may be installed but not on session PATH (winget user-scope install).
    # Check known paths before declaring "not found" -- same paths used post-install.
    # Verified: 2026-03-12 (NASM 3.01, winget user-scope)
    $nasmKnownPaths = @(
        "$env:LOCALAPPDATA\bin\NASM\nasm.exe",
        "$env:ProgramFiles\NASM\nasm.exe",
        "${env:ProgramFiles(x86)}\NASM\nasm.exe"
    )
    foreach ($p in $nasmKnownPaths) {
        if (Test-Path $p) {
            $env:PATH = "$(Split-Path $p);$env:PATH"
            Log "nasm found at $p (added to session PATH)"
            $nasmCheck = Get-Command nasm -ErrorAction SilentlyContinue
            break
        }
    }
}
if ($nasmCheck) {
    # 2>$null: the version is parsed from stdout only; an empty result is checked below.
    $nasmVer = (nasm --version 2>$null)
    if ($nasmVer) { $nasmVer = ($nasmVer -split '\s+' | Select-Object -Index 2) }
    LogOk "NASM found ($nasmVer)"
} else {
    Log "NASM not found -- installing via winget (needed by crypto crates like aws-lc-sys)..."
    $wingetOutput = winget install -e --id NASM.NASM --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    $nasmRc = $LASTEXITCODE
    if ($nasmRc -ne 0) {
        # Get-AitErrorReason logs the output as detail lines
        Write-AitAction "rust/cargo" "NASM not installed ($(Get-AitErrorReason -Output $wingetOutput -ExitCode $nasmRc)) -- some cargo builds will fail" "winget install NASM.NASM -- needed for aws-lc-sys crypto crates"
    } else {
        Log-WingetOutput $wingetOutput
        $nasmKnownPaths = @("$env:LOCALAPPDATA\bin\NASM\nasm.exe", "$env:ProgramFiles\NASM\nasm.exe", "${env:ProgramFiles(x86)}\NASM\nasm.exe")
        if (Ensure-ToolOnPath -ToolName "nasm" -KnownPaths $nasmKnownPaths) {
            LogOk "NASM installed and on PATH"
        } else {
            Write-AitAction "rust/cargo" "NASM installed but not on PATH -- restart the terminal" "Restart terminal or check NASM install location"
        }
    }
}

# --- Verify PATH persistence ---
$cargoBinDir = Join-Path $env:USERPROFILE ".cargo\bin"
$persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
if (-not (Test-Path $cargoPath)) {
    # The failed install above is the one error (one failure, one red line)
    Log "~/.cargo/bin not checked: cargo was not installed"
} elseif ($persistentPath -notlike "*$cargoBinDir*") {
    Write-AitError "rust/cargo" "installed but not on PATH" "$cargoBinDir is not in the persistent PATH"
    Write-Summary "ACTION" "" "Add $cargoBinDir to PATH -- cargo not accessible"
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
