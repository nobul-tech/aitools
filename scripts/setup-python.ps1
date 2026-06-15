# setup-python.ps1 -- Manages Python via uv (unified manager, Windows)
# Safe to re-run -- idempotent.
#
# uv is the single source of truth for Python on BOTH Windows and macOS. This
# script installs the target Python via uv and makes it the default, so bare
# `python`/`python3` resolve to the uv-managed interpreter (shims in uv's bin
# dir, %USERPROFILE%\.local\bin). Per-repo overrides use uv's normal mechanism
# (.python-version / `uv venv` / `uv run`) -- not a global rebind.
#
# Requires uv -- setup-uv.ps1 MUST run before this script.
#
# NOTE: Replaces the previous pymanager-based flow. A legacy pymanager, Microsoft
# Store (MSIX) Python, or winget Python.Python.3.x may still shadow the uv shim on
# PATH -- this script WARNS (does not auto-remove) so you can clean those up.
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

# Target Python version (bump here for future upgrades; mirrors setup-python.sh)
$targetPyVersion = "3.14"

# Refresh PATH to pick up tools installed by prior steps (e.g., setup-uv)
Refresh-Path

# --- Require uv (the manager) ---
# Get-Command exempt: command-existence check with explicit error/exit
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    LogError "uv not found -- setup-uv.ps1 must run before setup-python.ps1"
    Write-Summary "ERROR" "python" "uv not installed (ordering: uv before python)"
    exit 1
}

# --- Install/update the default Python via uv ---
# --default: install unversioned python/python3 executables into uv's bin dir.
# --preview-features python-install-default: silence the experimental warning and
#   pin the behavior (the --default flag is gated behind this preview feature).
Log "Installing/updating uv-managed Python $targetPyVersion as default..."
$installOutput = uv python install $targetPyVersion --default --upgrade --preview-features python-install-default 2>&1 | Out-String
$installOutput.Trim().Split("`n") | ForEach-Object {
    $l = $_.TrimEnd()
    if ($l.Trim()) { Log $l }
}
if ($LASTEXITCODE -ne 0) {
    LogError "uv python install failed (exit code $LASTEXITCODE)"
    Write-Summary "ERROR" "python" "uv python install failed"
    exit 1
}

Refresh-Path

# --- Verify python resolves to the uv-managed interpreter ---
# Get-Command exempt: command-existence check with if/else fallback
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
    $pyVersion = python --version 2>&1
    $src = $pythonCmd.Source
    if ($src -match '\\uv\\' -or $src -match '\.local\\bin') {
        LogOk "$pyVersion (uv-managed at $src)"
        Write-Summary "OK" "python" "$pyVersion (uv)"
    } else {
        LogWarn "python resolves to $src ($pyVersion), not the uv shim"
        LogWarn "A legacy pymanager / Microsoft Store / winget Python may be shadowing uv on PATH"
        LogWarn "Ensure uv's bin dir (%USERPROFILE%\.local\bin) precedes those in PATH"
        Write-Summary "WARN" "python" "$pyVersion (uv shim shadowed -- check PATH)"
        Write-Summary "ACTION" "" "Put %USERPROFILE%\.local\bin first in PATH -- python default"
    }
} else {
    LogError "'python' not found after uv install -- is uv's bin dir (%USERPROFILE%\.local\bin) on PATH?"
    Write-Summary "ERROR" "python" "python not on PATH after uv install"
    Write-Summary "ACTION" "" "Add %USERPROFILE%\.local\bin to PATH -- uv python shims"
}

# --- pip note ---
# uv-managed CPython bundles pip; prefer `uv pip` for project work.
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command pip -ErrorAction SilentlyContinue) {
    $pipVersion = pip --version 2>$null
    if ($pipVersion) { LogOk "pip available: $pipVersion" }
} else {
    Log "pip not on PATH as a standalone command -- use 'uv pip' or 'python -m pip'"
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
