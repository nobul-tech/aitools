# setup-vercelcli.ps1 — Installs/updates Vercel CLI on Windows
# Safe to re-run — detects existing install and skips if present.
#
# Windows: Uses npm install -g vercel (no winget package or standalone binary available).
# Verifies PATH after install so Claude Code's Bash tool can find the binary.
#
# See reference/tool-registry.md for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-vercelcli"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# Helper: refresh PATH from registry (picks up npm installs in same session)
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# --- Check npm ---
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    LogError "npm not found -- install Node.js first (aitools install handles this)"
    exit 1
}

# --- Install/update ---
if (Get-Command vercel -ErrorAction SilentlyContinue) {
    $vercelVersion = (vercel --version 2>$null | Select-Object -First 1)
    LogOk "Vercel CLI already installed ($vercelVersion)"
    Write-Summary "OK" "vercel cli" "$vercelVersion"
} else {
    Log "Installing Vercel CLI via npm..."
    $npmOutput = npm install -g vercel 2>&1 | Out-String
    $npmOutput.Trim().Split("`n") | ForEach-Object { Log $_.TrimEnd() }
    if ($LASTEXITCODE -ne 0) {
        LogError "npm install failed (exit code $LASTEXITCODE)"
        Write-Summary "ERROR" "vercel cli" "npm install failed (exit $LASTEXITCODE)"
    }
    Refresh-Path

    if (Get-Command vercel -ErrorAction SilentlyContinue) {
        $vercelVersion = (vercel --version 2>$null | Select-Object -First 1)
        $vercelPath = (Get-Command vercel).Source
        LogOk "Vercel CLI installed ($vercelVersion)"
        Log "Install path: $vercelPath"
        Write-Summary "OK" "vercel cli" "$vercelVersion"

        # Verify the install directory is in persistent PATH (not just this session)
        $vercelDir = Split-Path $vercelPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$vercelDir*") {
            LogError "Vercel install dir not in persistent PATH: $vercelDir"
            Write-Summary "ERROR" "vercel cli" "installed but not on PATH"
            LogWarn "Add $vercelDir to PATH -- tool not accessible to Claude Code"
            Write-Summary "ACTION" "" "Add $vercelDir to PATH -- vercel not accessible"
        }
    } else {
        LogError "Vercel CLI install failed"
        Write-Summary "ERROR" "vercel cli" "install failed"
        $npmPrefix = (npm config get prefix 2>$null)
        Log "npm global prefix: $npmPrefix"
        Log "Check that $npmPrefix is in your PATH"
    }
}

# Only suggest auth if vercel is installed but not authenticated
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command vercel -ErrorAction SilentlyContinue) {
    $vercelWhoami = & vercel whoami 2>$null
    if ($LASTEXITCODE -ne 0) {
        LogWarn "Authentication required: run 'vercel login' to authenticate"
        Write-Summary "ACTION" "" "vercel login -- authenticate vercel CLI"
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
