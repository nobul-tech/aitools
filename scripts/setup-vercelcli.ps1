# setup-vercelcli.ps1 — Installs/updates Vercel CLI on Windows
# Safe to re-run — detects existing install and skips if present.
#
# Windows: Uses npm install -g vercel (no winget package or standalone binary available).
# Verifies PATH after install so Claude Code's Bash tool can find the binary.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

# --- Shared library ---
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "aitools-lib.ps1")
Initialize-Logging "setup-vercelcli"

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# Log captured command output to the log file as detail lines (blank lines skipped).
function Write-OutputDetail([string]$Label, [string]$Output) {
    foreach ($l in $Output.Split("`n")) { if ($l.Trim()) { LogDetail "${Label}: $($l.TrimEnd())" } }
}

# Get-VercelVersion: first line of `vercel --version` with a version number. A failed
# probe logs its output and returns "version unknown"; the install result is decided
# by the npm exit code, not by this probe.
function Get-VercelVersion {
    $out = & vercel --version 2>&1 | Out-String
    $rc = $LASTEXITCODE
    if ($rc -eq 0) {
        foreach ($l in $out.Split("`n")) { if ($l -match '\d+\.\d+\.\d+') { return $l.Trim() } }
    }
    Write-OutputDetail "vercel-version (exit $rc)" $out
    return "version unknown"
}

# --- Check npm ---
# Get-Command exempt: command-existence check with if/else fallback
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-AitError "vercel cli" "npm not found" "npm is not on PATH -- install Node.js first (aitools install does)"
    exit 1
}

# --- Install/update ---
# Get-Command exempt: command-existence check with if/else fallback
if (Get-Command vercel -ErrorAction SilentlyContinue) {
    $vercelVersion = Get-VercelVersion
    LogOk "Vercel CLI already installed ($vercelVersion)"
    Write-Summary "OK" "vercel cli" "$vercelVersion"
} else {
    Log "Installing Vercel CLI via npm..."
    # Exit code decides (C-F2); the full output goes to the log as detail.
    $npmOutput = npm install -g vercel 2>&1 | Out-String
    $npmRc = $LASTEXITCODE
    if ($npmRc -eq 0) { Write-OutputDetail "npm-install-vercel" $npmOutput }
    Refresh-Path

    # Get-Command exempt: command-existence check with if/else fallback
    if ($npmRc -ne 0) {
        # Get-AitErrorReason logs the output as detail lines (logging.md 8.2)
        Write-AitError "vercel cli" "npm install failed" (Get-AitErrorReason -Output $npmOutput -ExitCode $npmRc)
    } elseif (Get-Command vercel -ErrorAction SilentlyContinue) {
        $vercelVersion = Get-VercelVersion
        $vercelPath = (Get-Command vercel).Source
        LogOk "Vercel CLI installed ($vercelVersion)"
        Log "Install path: $vercelPath"

        # Verify the install directory is in persistent PATH (not just this session)
        $vercelDir = Split-Path $vercelPath -Parent
        $persistentPath = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($persistentPath -notlike "*$vercelDir*") {
            Write-AitError "vercel cli" "installed but not on PATH" "$vercelDir is not in the persistent PATH"
            Write-Summary "ACTION" "" "Add $vercelDir to PATH -- vercel not accessible"
        } else {
            Write-Summary "OK" "vercel cli" "$vercelVersion"
        }
    } else {
        Write-AitError "vercel cli" "installed but not on PATH" "Get-Command vercel found nothing after npm install -g"
        $npmPrefix = npm config get prefix 2>&1 | Out-String
        $prefixRc = $LASTEXITCODE
        if ($prefixRc -eq 0) {
            Log "Check that the npm global prefix is in your PATH: $($npmPrefix.Trim())"
        } else {
            Write-OutputDetail "npm-config-get-prefix (exit $prefixRc)" $npmPrefix
        }
    }
}

# --- Auth status check (script-standards-detail.md: command exit code pattern) ---
# Gated on the script's own error count (the helpers still raise it).
# Get-Command exempt: command-existence check with explicit fallback
if ((Get-Command vercel -ErrorAction SilentlyContinue) -and $errors -eq 0) {
    $whoamiOutput = & vercel whoami 2>&1 | Out-String
    $whoamiRc = $LASTEXITCODE
    if ($whoamiRc -ne 0) {
        Write-OutputDetail "vercel-whoami (exit $whoamiRc)" $whoamiOutput
        Write-AitAction "vercel cli" "not authenticated -- run: vercel login" "vercel login -- authenticate vercel CLI"
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
