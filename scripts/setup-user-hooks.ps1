# setup-user-hooks.ps1 -- Deploys Claude Code hooks to ~/.claude/settings.json
# Safe to re-run -- merges hook config without clobbering existing settings.
#
# Adds a SessionEnd hook that archives session transcripts to the user repo.
# See reference/user-repo.md and shared/hooks/session-archive.sh for details.
#
# Note: The hook script itself is bash-only (Claude Code hooks always run in
# bash on both platforms). This PS1 script only deploys the hook configuration.

# --- Logging ---
$logDir = Join-Path $env:LOCALAPPDATA "ai-tooling"
$logFile = Join-Path $logDir "deploy.log"
$scriptName = "setup-user-hooks"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}
function LogOk($msg)    { Log "OK: $msg" }
function LogError($msg) { Log "ERROR: $msg" }
function LogWarn($msg)  { Log "WARN: $msg" }

# --- OS guard ---
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}

# --- Resolve repo path ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = Split-Path -Parent $scriptDir

$hookScript = Join-Path $repoDir "shared\hooks\session-archive.sh"
if (-not (Test-Path $hookScript)) {
    LogError "Hook script not found: $hookScript"
    exit 1
}

# --- Require node for JSON manipulation ---
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    LogError "node required for JSON manipulation"
    exit 1
}

# --- Merge hook into ~/.claude/settings.json ---
$settingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }

# Hook command uses Unix-style path (hooks run in bash even on Windows)
# Convert backslashes to forward slashes for the bash command
$hookScriptUnix = $hookScript -replace '\\', '/'
$hookCmd = "bash `"$hookScriptUnix`""

node -e @"
const fs = require('fs');
const settingsFile = process.argv[1];
const hookCmd = process.argv[2];

let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8')); } catch {}

if (!settings.hooks) settings.hooks = {};
if (!Array.isArray(settings.hooks.SessionEnd)) settings.hooks.SessionEnd = [];

// Check if our hook is already installed (by matching the command prefix)
const hookId = 'session-archive.sh';
const existing = settings.hooks.SessionEnd.find(rule =>
    rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId))
);

if (existing) {
    // Update the command path in case repo moved
    existing.hooks.forEach(h => {
        if (h.command && h.command.includes(hookId)) {
            h.command = hookCmd;
        }
    });
} else {
    // Add new hook entry
    settings.hooks.SessionEnd.push({
        matcher: '',
        hooks: [{
            type: 'command',
            command: hookCmd
        }]
    });
}

fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');
"@ "$settingsFile" "$hookCmd"

LogOk "SessionEnd hook deployed to $settingsFile"
Log "  Hook: $hookCmd"
