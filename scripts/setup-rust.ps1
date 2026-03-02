# setup-rust.ps1 — Installs/updates Rust toolchain (rustup + cargo) on Windows
# Safe to re-run — detects existing install and upgrades as needed.
#
# Windows: Uses winget to install rustup, which manages the Rust toolchain.
# Checks for MSVC Build Tools (required for linking) and warns if missing.
#
# See reference/tool-registry.md for install source details.

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "aitools"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-rust"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
$errors = 0
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg"; $script:errors++ }
function LogWarn($msg)  { Log "WARN: $msg" }

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
$cargoPath = Join-Path $env:USERPROFILE ".cargo\bin\cargo.exe"

if (Test-Path $cargoPath) {
    Log "rustup found -- updating toolchain..."
    $rustupExe = Join-Path $env:USERPROFILE ".cargo\bin\rustup.exe"
    & $rustupExe update 2>&1 | Select-Object -Last 3 | ForEach-Object { Log $_ }
    $cargoVersion = (& $cargoPath --version 2>$null)
    $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
    $rustcVersion = (& $rustcPath --version 2>$null)
    LogOk "cargo $cargoVersion"
    LogOk "rustc $rustcVersion"
} else {
    Log "Installing Rust toolchain via winget..."
    winget install -e --id Rustlang.Rustup --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { Log $_ }
    Refresh-Path

    if (Test-Path $cargoPath) {
        $cargoVersion = (& $cargoPath --version 2>$null)
        $rustcPath = Join-Path $env:USERPROFILE ".cargo\bin\rustc.exe"
        $rustcVersion = (& $rustcPath --version 2>$null)
        LogOk "Rust toolchain installed"
        LogOk "cargo $cargoVersion"
        LogOk "rustc $rustcVersion"
    } else {
        LogError "winget install completed but cargo not found at $cargoPath"
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
}

# --- Verify PATH persistence ---
$cargoBinDir = Join-Path $env:USERPROFILE ".cargo\bin"
$persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($persistentPath -notlike "*$cargoBinDir*") {
    LogWarn "~/.cargo/bin not in persistent PATH: $cargoBinDir"
    LogWarn "Claude Code may not find 'cargo'. Add this directory to your User PATH."
}

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
