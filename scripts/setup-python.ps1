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
# PATH -- this script reports the shadowed shim as an error, with an ACTION (D-TS11),
# and does not auto-remove it, so you can clean those up.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
    Write-AitError "python" "uv not installed" "uv is not on PATH; setup-uv must run before setup-python"
    exit 1
}

# --- Install/update the default Python via uv ---
# --default: install unversioned python/python3 executables into uv's bin dir.
# --preview-features python-install-default: silence the experimental warning and
#   pin the behavior (the --default flag is gated behind this preview feature).
# --upgrade: only on uv versions that support it (older uv rejects the flag and the
#   whole install fails); without it an already-installed $targetPyVersion is kept as is.
$upgradeArgs = @()
# The help text is the result -- checked for the flag immediately below
$uvInstallHelp = uv python install --help 2>&1 | Out-String
if ($uvInstallHelp -match '--upgrade') {
    $upgradeArgs = @('--upgrade')
} else {
    $uvVersion = (uv --version 2>&1 | Out-String).Trim()
    Write-AitAction "python" "$uvVersion is too old for 'uv python install --upgrade' (installing without it) -- upgrade uv" "Upgrade uv, then re-run aitools install"
}
Log "Installing/updating uv-managed Python $targetPyVersion as default..."
$installOutput = uv python install $targetPyVersion --default @upgradeArgs --preview-features python-install-default 2>&1 | Out-String
$installRc = $LASTEXITCODE
if ($installRc -ne 0) {
    # Get-AitErrorReason logs the output as detail lines
    Write-AitError "python" "uv python install failed" (Get-AitErrorReason -Output $installOutput -ExitCode $installRc)
    exit 1
}
$installOutput.Trim().Split("`n") | ForEach-Object {
    $l = $_.TrimEnd()
    if ($l.Trim()) { Log $l }
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
        # A shadowed managed tool is an error, plus an ACTION (D-TS11;
        # script-standards-detail "Severity decision guide")
        $shadowDir = Split-Path $src -Parent
        Write-AitError "python" "shadowed" "python resolves to $src ($pyVersion), not the uv shim at $env:USERPROFILE\.local\bin\python.exe"
        Log "$shadowDir precedes %USERPROFILE%\.local\bin in PATH -- the uv shim is shadowed (legacy pymanager / MS Store / winget Python?)"
        Write-Summary "ACTION" "" "Put %USERPROFILE%\.local\bin before $shadowDir in PATH -- python default"
    }
} else {
    Write-AitError "python" "python not on PATH after uv install" "Get-Command python found nothing; %USERPROFILE%\.local\bin is probably not on PATH"
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
