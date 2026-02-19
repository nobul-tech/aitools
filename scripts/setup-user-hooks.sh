#!/usr/bin/env bash
# setup-user-hooks.sh — Deploys Claude Code hooks to ~/.claude/settings.json
# Safe to re-run — merges hook config without clobbering existing settings.
#
# Adds a SessionEnd hook that archives session transcripts to the user repo.
# See reference/user-repo.md and shared/hooks/session-archive.sh for details.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/ai-tooling"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ai-tooling"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-user-hooks"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Resolve repo path ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOK_SCRIPT="$REPO_DIR/shared/hooks/session-archive.sh"
if [ ! -f "$HOOK_SCRIPT" ]; then
    log_error "Hook script not found: $HOOK_SCRIPT"
    exit 1
fi

# --- Require node for JSON manipulation ---
if ! command -v node &>/dev/null; then
    log_error "node required for JSON manipulation"
    exit 1
fi

# --- Merge hook into ~/.claude/settings.json ---
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

# The hook command — uses absolute path to the repo
HOOK_CMD="bash \"$HOOK_SCRIPT\""

node -e "
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
" "$SETTINGS_FILE" "$HOOK_CMD"

log_ok "SessionEnd hook deployed to $(display_path "$SETTINGS_FILE")"
log "  Hook: $HOOK_CMD"

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
