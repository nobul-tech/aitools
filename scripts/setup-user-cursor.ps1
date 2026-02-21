# setup-user-cursor.ps1 — Sets up Cursor CLI + dependencies on Windows
# Safe to re-run — checks each step and skips what's already done.
# Install commands reference: reference/tool-install-sources.md
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-cursor"
$errors = 0
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg"; $script:errors++ }
function LogWarn($msg)  { Log "WARN: $msg" }

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

$cursorDir = Join-Path $env:USERPROFILE ".cursor"
$cliConfig = Join-Path $cursorDir "cli-config.json"

# Track status for summary
$status = @{
    ripgrep   = ""
    cursorCli = ""
    cliConfig = ""
}

# Helper: refresh PATH from registry (picks up winget installs in same session)
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# --- 1. ripgrep (rg) ---

Log "Step 1: ripgrep (rg)"

$rgCmd = Get-Command rg -ErrorAction SilentlyContinue
if ($rgCmd) {
    $rgVersion = (rg --version | Select-Object -First 1)
    LogOk "Already installed: $rgVersion"
    $status.ripgrep = "already installed ($rgVersion)"
} else {
    Log "Installing ripgrep via winget..."
    winget install BurntSushi.ripgrep.MSVC --accept-package-agreements --accept-source-agreements
    Refresh-Path

    $rgCmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($rgCmd) {
        $rgVersion = (rg --version | Select-Object -First 1)
        LogOk "Installed: $rgVersion"
        $status.ripgrep = "installed ($rgVersion)"
    } else {
        LogWarn "winget install completed but 'rg' not found in PATH. Restart terminal to verify."
        $status.ripgrep = "installed (restart terminal to verify)"
    }
}

# --- 2. Cursor CLI (agent) ---

Log "Step 2: Cursor CLI (agent)"

$agentCmd = Get-Command agent -ErrorAction SilentlyContinue
if ($agentCmd) {
    $agentVersion = agent --version
    LogOk "Already installed: $agentVersion"
    $status.cursorCli = "already installed ($agentVersion)"
} else {
    Log "Installing Cursor CLI..."
    Invoke-Expression (Invoke-RestMethod 'https://cursor.com/install?win32=true')

    $agentCmd = Get-Command agent -ErrorAction SilentlyContinue
    if ($agentCmd) {
        $agentVersion = agent --version
        LogOk "Installed: $agentVersion"
        $status.cursorCli = "installed ($agentVersion)"
    } else {
        LogWarn "Cursor CLI install completed but 'agent' not found in PATH. Restart terminal to verify."
        $status.cursorCli = "installed (restart terminal to verify)"
    }
}

# --- 3. cli-config.json (merge, not overwrite) ---

Log "Step 3: cli-config.json"

# Ensure ~/.cursor/ exists
if (-not (Test-Path $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
    Log "Created $cursorDir"
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    LogWarn "node not found -- skipping cli-config.json merge"
    $status.cliConfig = "SKIPPED (node not found)"
} else {
    # Read cursor.cli preferences from profile.json (via config.json -> userRepoPath).
    # Falls back to defaults if profile not found. Uses node for JSON merge
    # (same pattern as setup-user-mcp.ps1 settings merge).

    $mergeResult = & node -e @'
const fs = require('fs');
const path = require('path');
const f = process.argv[1];

// --- Read profile preferences ---
let vimMode = false;
let modelId = 'auto';
try {
    const cfgPath = path.join(process.env.HOME || process.env.USERPROFILE, '.config', 'ai-tooling', 'config.json');
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    if (cfg.userRepoPath) {
        const pf = JSON.parse(fs.readFileSync(path.join(cfg.userRepoPath, 'profile.json'), 'utf8'));
        if (pf.cursor && pf.cursor.cli) {
            if (typeof pf.cursor.cli.vimMode === 'boolean') vimMode = pf.cursor.cli.vimMode;
            if (typeof pf.cursor.cli.model === 'string') modelId = pf.cursor.cli.model;
        }
    }
} catch {}

// --- Read existing cli-config.json ---
let config = {};
try { config = JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}
const before = JSON.stringify(config);

// --- Merge managed fields ---
config.version = 1;
if (!config.editor) config.editor = {};
config.editor.vimMode = vimMode;
if (!config.permissions) config.permissions = {};
if (!Array.isArray(config.permissions.allow)) config.permissions.allow = [];
if (!Array.isArray(config.permissions.deny)) config.permissions.deny = [];

// Model: only set if profile specifies 'auto' (the only supported value for now)
if (modelId === 'auto') {
    config.model = {
        modelId: 'default',
        displayModelId: 'auto',
        displayName: 'Auto',
        displayNameShort: 'Auto',
        aliases: ['auto'],
        maxMode: false
    };
    config.hasChangedDefaultModel = true;
}

// All other fields (authInfo, privacyCache, network, statsigBootstrap, maxMode, etc.)
// are preserved -- we never delete keys we don't manage.

const after = JSON.stringify(config);
if (before === after) {
    console.log('unchanged');
} else {
    fs.writeFileSync(f, JSON.stringify(config, null, 2) + '\n');
    console.log(before === '{}' ? 'created' : 'merged');
}
'@ $cliConfig

    switch ($mergeResult) {
        "unchanged" {
            LogOk "Already up to date: $cliConfig"
            $status.cliConfig = "already up to date"
        }
        "created" {
            LogOk "Created: $cliConfig"
            $status.cliConfig = "created"
        }
        "merged" {
            LogOk "Merged preferences into: $cliConfig"
            $status.cliConfig = "merged"
        }
        default {
            LogError "Unexpected merge result: $mergeResult"
            $status.cliConfig = "ERROR"
        }
    }
}

# --- Summary ---

Log "=============================="
Log "Summary:"
Log "  ripgrep:       $($status.ripgrep)"
Log "  Cursor CLI:    $($status.cursorCli)"
Log "  cli-config:    $($status.cliConfig)"
Log "=============================="

# --- Exit ---
if ($errors -gt 0) {
    Log "FAILED with $errors error(s). See log: $logFile"
    exit 1
} else {
    Log "COMPLETED successfully"
    exit 0
}
