# setup-rust.ps1 — Installs/updates Rust toolchain (rustup + cargo) on Windows
# Safe to re-run — detects existing install and upgrades as needed.
#
# Windows: Uses winget to install rustup, which manages the Rust toolchain.
# Checks for MSVC Build Tools (required for linking) and warns if missing.
#
# See reference/tool-registry.md for install source details.

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
    $rustupOutput.Trim().Split("`n") | Select-Object -Last 3 | ForEach-Object { $l = $_.TrimEnd(); if ($l.Trim()) { Log $l } }
    if ($LASTEXITCODE -ne 0) {
        LogError "rustup update failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "rust/cargo" "rustup update failed (exit $LASTEXITCODE)"
    } else {
        $cargoVersion = (& $cargoPath --version 2>$null)
        $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
        $rustcVersion = (& $rustcPath --version 2>$null)
        LogOk "cargo $cargoVersion"
        LogOk "rustc $rustcVersion"
        Write-Summary "OK" "rust/cargo" "$cargoVersion"
    }
} else {
    Log "Installing Rust toolchain via winget..."
    $wingetOutput = winget install -e --id Rustlang.Rustup --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    Log-WingetOutput $wingetOutput
    if ($LASTEXITCODE -ne 0) {
        LogError "winget install rustup failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "rust/cargo" "winget install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path

    if (Test-Path $cargoPath) {
        $cargoVersion = (& $cargoPath --version 2>$null)
        $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
        $rustcVersion = (& $rustcPath --version 2>$null)
        LogOk "Rust toolchain installed"
        LogOk "cargo $cargoVersion"
        LogOk "rustc $rustcVersion"
        Write-Summary "OK" "rust/cargo" "$cargoVersion"
    } else {
        LogError "winget install completed but cargo not found at $cargoPath"
        Write-Summary "ERROR" "rust/cargo" "install failed (cargo not found)"
    }
}

# --- MSVC Build Tools check ---
# Rust on Windows requires MSVC Build Tools for linking.
# Check common install locations for VS Build Tools or Visual Studio with VC tools.
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$hasMSVC = $false
if (Test-Path $vsWhere) {
    $vsInstalls = & $vsWhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($vsInstalls) { $hasMSVC = $true }
}

if ($hasMSVC) {
    LogOk "MSVC Build Tools found"
} else {
    LogWarn "MSVC Build Tools not detected -- cargo build will fail without a C linker"
    LogWarn "Install: winget install Microsoft.VisualStudio.2022.BuildTools"
    LogWarn "  Then add workload: Desktop Development with C++"
    Write-Summary "WARN" "rust/cargo" "MSVC Build Tools not detected -- cargo build will fail without a C linker"
}

# --- Build tool prerequisites (NASM, CMake, etc.) ---
# These are not needed by Rust itself, but by commonly used crates (aws-lc-sys, etc.)
# Get-Command exempt: command-existence check with explicit fallback
$nasmCheck = Get-Command nasm -ErrorAction SilentlyContinue
if ($nasmCheck) {
    $nasmVer = (nasm --version 2>$null)
    if ($nasmVer) { $nasmVer = ($nasmVer -split '\s+' | Select-Object -Index 2) }
    LogOk "NASM found ($nasmVer)"
} else {
    Log "NASM not found -- installing via winget (needed by crypto crates like aws-lc-sys)..."
    $wingetOutput = winget install -e --id NASM.NASM --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    Log-WingetOutput $wingetOutput
    if ($LASTEXITCODE -ne 0) {
        LogWarn "winget install NASM failed (exit $LASTEXITCODE)"
        Write-Summary "WARN" "rust/cargo" "NASM not installed -- some cargo builds will fail"
        Write-Summary "ACTION" "" "winget install NASM.NASM -- needed for aws-lc-sys crypto crates"
    } else {
        Refresh-Path
        # Get-Command exempt: command-existence check with explicit fallback
        $nasmCheck = Get-Command nasm -ErrorAction SilentlyContinue
        if ($nasmCheck) {
            LogOk "NASM installed"
        } else {
            LogWarn "NASM installed but not on PATH -- restart terminal"
            Write-Summary "WARN" "rust/cargo" "NASM installed but not on PATH"
            Write-Summary "ACTION" "" "Restart terminal -- NASM needs PATH refresh"
        }
    }
}

# --- Verify PATH persistence ---
$cargoBinDir = Join-Path $env:USERPROFILE ".cargo\bin"
$persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($persistentPath -notlike "*$cargoBinDir*") {
    LogError "~/.cargo/bin not in persistent PATH: $cargoBinDir"
    Write-Summary "ERROR" "rust/cargo" "installed but not on PATH"
    LogWarn "Add $cargoBinDir to PATH -- tool not accessible to Claude Code"
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
