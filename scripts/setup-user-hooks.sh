#!/usr/bin/env bash
# setup-user-hooks.sh — Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Safe to re-run — merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, autoMemoryEnabled, alwaysThinkingEnabled
# Preserved: permissions, enabledPlugins, all other fields
#
# Adds a SessionEnd hook that archives session transcripts to the user repo.
# Reads claude preferences from profile.json (via config.json -> userRepoPath).
# See reference/user-repo.md and shared/hooks/session-archive.sh for details.

set -euo pipefail

# --- Flag parsing ---
DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
    esac
done
[ "${AITOOLS_DRY_RUN:-}" = "1" ] && DRY_RUN=true

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
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

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

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

# --- Deploy hook script to ~/.claude/hooks/ ---
HOOK_DEST="$HOME/.claude/hooks/session-archive.sh"

if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would deploy hook: $(display_path "$HOOK_SCRIPT") -> $(display_path "$HOOK_DEST")"
else
    mkdir -p "$HOME/.claude/hooks"
    cp "$HOOK_SCRIPT" "$HOOK_DEST"
    chmod +x "$HOOK_DEST"
    log_ok "Deployed hook: $(display_path "$HOOK_DEST")"
fi

# --- Merge hook into ~/.claude/settings.json ---
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

# The hook command — uses deployed copy in ~/.claude/hooks/
HOOK_CMD="bash \"$HOOK_DEST\""

MERGE_RESULT=$(node -e "
const fs = require('fs');
const path = require('path');
const settingsFile = process.argv[1];
const hookCmd = process.argv[2];
const dryRun = process.argv[3] === 'true';
const force = process.argv[4] === 'true';

// --- Read claude preferences from profile.json ---
let autoMemory = true;
let alwaysThinking = true;
try {
    const cfgPath = path.join(process.env.HOME || process.env.USERPROFILE, '.aitools', 'config.json');
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    if (cfg.userRepoPath) {
        const pf = JSON.parse(fs.readFileSync(path.join(cfg.userRepoPath, 'profile.json'), 'utf8'));
        if (pf.claude) {
            if (typeof pf.claude.autoMemory === 'boolean') autoMemory = pf.claude.autoMemory;
            if (typeof pf.claude.alwaysThinking === 'boolean') alwaysThinking = pf.claude.alwaysThinking;
        }
    }
} catch (e) { if (e.code !== 'ENOENT') console.error('Warning: could not read profile preferences: ' + e.message); }

// --- Read existing settings.json ---
let settings = {};
let corrupt = false;
try {
    settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
} catch (e) {
    if (e.code !== 'ENOENT') {
        corrupt = true;
        console.error('Warning: ' + settingsFile + ' is invalid JSON');
    }
}
const beforeKeys = Object.keys(settings);

// --- Merge hook ---
if (!settings.hooks) settings.hooks = {};
if (!Array.isArray(settings.hooks.SessionEnd)) settings.hooks.SessionEnd = [];

const hookId = 'session-archive.sh';
const existing = settings.hooks.SessionEnd.find(rule =>
    rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId))
);

if (existing) {
    existing.hooks.forEach(h => {
        if (h.command && h.command.includes(hookId)) {
            h.command = hookCmd;
        }
    });
} else {
    settings.hooks.SessionEnd.push({
        matcher: '',
        hooks: [{
            type: 'command',
            command: hookCmd
        }]
    });
}

// --- Merge claude preferences ---
settings.autoMemoryEnabled = autoMemory;
settings.alwaysThinkingEnabled = alwaysThinking;

// --- Clobber detection ---
const managedKeys = ['hooks', 'autoMemoryEnabled', 'alwaysThinkingEnabled'];
const afterKeys = Object.keys(settings);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

if (dryRun) {
    console.error('[DRY RUN] ' + settingsFile + ': merge');
    console.error('  Managed fields: ' + managedKeys.join(', '));
    if (lostKeys.length > 0) console.error('  CLOBBER WARNING: would lose: ' + lostKeys.join(', '));
    if (corrupt) console.error('  File is corrupt -- --force required');
    console.error('  Hook: ' + hookCmd);
    console.error('  autoMemoryEnabled: ' + autoMemory);
    console.error('  alwaysThinkingEnabled: ' + alwaysThinking);
    console.log('dry-run');
} else if (corrupt && !force) {
    console.error('ERROR: ' + settingsFile + ' is corrupt. Use --force to overwrite, or fix manually.');
    console.log('error-corrupt');
} else if (lostKeys.length > 0 && !force) {
    console.error('ERROR: merge would lose fields: ' + lostKeys.join(', ') + '. Use --force to proceed.');
    console.log('error-clobber');
} else {
    if (corrupt) console.error('Warning: proceeding with --force on corrupt file');
    if (lostKeys.length > 0) console.error('Warning: proceeding with --force, losing fields: ' + lostKeys.join(', '));
    fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');

    // Post-write validation
    const _v = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
    const _missing = ['hooks', 'autoMemoryEnabled', 'alwaysThinkingEnabled'].filter(k => !(k in _v));
    if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }

    console.log('ok');
}
" "$SETTINGS_FILE" "$HOOK_CMD" "$DRY_RUN" "$FORCE")

case "$MERGE_RESULT" in
    ok)
        log_ok "Settings deployed to $(display_path "$SETTINGS_FILE")"
        log "  Hook: $HOOK_CMD"
        log "  autoMemoryEnabled: $(node -e "console.log(JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8')).autoMemoryEnabled)")"
        log "  alwaysThinkingEnabled: $(node -e "console.log(JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8')).alwaysThinkingEnabled)")"
        ;;
    dry-run)
        log "[DRY RUN] Would merge settings (see above)"
        ;;
    error-corrupt)
        log_error "$(display_path "$SETTINGS_FILE") is corrupt. Use --force to overwrite."
        ;;
    error-clobber)
        log_error "$(display_path "$SETTINGS_FILE") merge would lose fields. Use --force to proceed."
        ;;
    *)
        log_error "Unexpected merge result: $MERGE_RESULT"
        ;;
esac

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
