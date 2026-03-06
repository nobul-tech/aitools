#!/usr/bin/env bash
# setup-user-hooks.sh — Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Safe to re-run — merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.PreToolUse, autoMemoryEnabled, alwaysThinkingEnabled, effortLevel
# Preserved: permissions, enabledPlugins, all other fields
#
# Hooks deployed:
#   SessionEnd: session-archive.sh (archives transcripts to user repo)
#   PreToolUse[Bash]: standing-order-guard.sh (enforces standing orders on Bash commands)
#
# Reads claude preferences from profile.json (via config.json -> userRepoPath).
# See reference/user-repo.md and shared/hooks/ for details.

# --- BEGIN hooks body (extracted by build-deploy) ---
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

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-user-hooks"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

# --- Require node for JSON manipulation ---
if ! command -v node &>/dev/null; then
    log_error "node required for JSON manipulation"
    exit 1
fi

# --- BEGIN hook deployment (replaced by build-deploy) ---
# --- Resolve repo path ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOK_SCRIPT="$REPO_DIR/shared/hooks/session-archive.sh"
GUARD_SCRIPT="$REPO_DIR/shared/hooks/standing-order-guard.sh"
for src in "$HOOK_SCRIPT" "$GUARD_SCRIPT"; do
    if [ ! -f "$src" ]; then
        log_error "Hook script not found: $src"
        exit 1
    fi
done

# --- Deploy hook scripts to ~/.claude/hooks/ ---
HOOK_DEST="$HOME/.claude/hooks/session-archive.sh"
GUARD_DEST="$HOME/.claude/hooks/standing-order-guard.sh"

HOOKS_CHANGED=false

if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would deploy hook: $(display_path "$HOOK_SCRIPT") -> $(display_path "$HOOK_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$GUARD_SCRIPT") -> $(display_path "$GUARD_DEST")"
else
    mkdir -p "$HOME/.claude/hooks"
    HOOKS_UPDATED=0
    for hook_pair in "$HOOK_SCRIPT|$HOOK_DEST" "$GUARD_SCRIPT|$GUARD_DEST"; do
        hook_src="${hook_pair%%|*}"
        hook_dst="${hook_pair##*|}"
        hook_name=$(basename "$hook_dst")
        # diff -q exits 0 when files are identical; suppress output (we only care about result)
        if [ -f "$hook_dst" ] && diff -q "$hook_src" "$hook_dst" >/dev/null 2>&1; then
            log_ok "Hook unchanged: $hook_name"
        else
            # Log unified diff when updating existing hook
            if [ -f "$hook_dst" ]; then
                diff_exit=0
                diff -u "$hook_dst" "$hook_src" >> "$LOG_FILE" 2>&1 || diff_exit=$?
                # diff exits 1 for differences (expected), 2+ for errors
                [ "$diff_exit" -le 1 ] || log_warn "diff failed for $hook_name (exit $diff_exit)"
            fi
            cp "$hook_src" "$hook_dst"
            chmod +x "$hook_dst"
            log_ok "Deployed hook: $(display_path "$hook_dst")"
            HOOKS_CHANGED=true
            HOOKS_UPDATED=$((HOOKS_UPDATED + 1))
            write_summary DETAIL "claude hooks" "hook updated: $hook_name"
        fi
    done
fi
# --- END hook deployment (replaced by build-deploy) ---

# --- Merge hook into ~/.claude/settings.json ---
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

# The hook commands — use deployed copies in ~/.claude/hooks/
HOOK_CMD="bash \"$HOOK_DEST\""
GUARD_CMD="bash \"$GUARD_DEST\""

MERGE_RESULT=$(node -e "
$SORT_KEYS_JS
const fs = require('fs');
const path = require('path');
const settingsFile = process.argv[1];
const hookCmd = process.argv[2];
const guardCmd = process.argv[3];
const dryRun = process.argv[4] === 'true';
const force = process.argv[5] === 'true';

// --- BEGIN claude preferences (replaced by build-deploy) ---
let autoMemory = true;
let alwaysThinking = true;
let effortLevel = null;
const validEffortLevels = ['low', 'medium', 'high'];
try {
    const cfgPath = path.join(process.env.HOME || process.env.USERPROFILE, '.aitools', 'config.json');
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    if (cfg.userRepoPath) {
        const pf = JSON.parse(fs.readFileSync(path.join(cfg.userRepoPath, 'profile.json'), 'utf8'));
        if (pf.claude) {
            if (typeof pf.claude.autoMemory === 'boolean') autoMemory = pf.claude.autoMemory;
            if (typeof pf.claude.alwaysThinking === 'boolean') alwaysThinking = pf.claude.alwaysThinking;
            if (typeof pf.claude.effortLevel === 'string' && validEffortLevels.includes(pf.claude.effortLevel)) {
                effortLevel = pf.claude.effortLevel;
            } else if (pf.claude.effortLevel !== undefined) {
                console.error('Warning: invalid effortLevel "' + pf.claude.effortLevel + '" (valid: ' + validEffortLevels.join(', ') + ')');
            }
        }
    }
} catch (e) { if (e.code !== 'ENOENT') console.error('Warning: could not read profile preferences: ' + e.message); }
// --- END claude preferences (replaced by build-deploy) ---

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

// --- Merge hooks ---
if (!settings.hooks) settings.hooks = {};

// Helper: ensure exactly one entry for a hookId in an event array.
// Updates the command if found, adds if not, deduplicates extras.
function mergeHookEntry(eventName, hookId, matcher, cmd) {
    if (!Array.isArray(settings.hooks[eventName])) settings.hooks[eventName] = [];
    const arr = settings.hooks[eventName];

    // Find first matching entry and update it
    let found = false;
    for (const rule of arr) {
        if (rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId))) {
            if (!found) {
                rule.hooks.forEach(h => {
                    if (h.command && h.command.includes(hookId)) h.command = cmd;
                });
                rule.matcher = matcher;
                found = true;
            }
        }
    }
    if (!found) {
        arr.push({ matcher, hooks: [{ type: 'command', command: cmd }] });
    }

    // Deduplicate: keep only the first entry matching hookId
    let seen = false;
    settings.hooks[eventName] = arr.filter(rule => {
        const isMatch = rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId));
        if (isMatch) {
            if (seen) return false;
            seen = true;
        }
        return true;
    });
}

mergeHookEntry('SessionEnd', 'session-archive.sh', '', hookCmd);
mergeHookEntry('PreToolUse', 'standing-order-guard.sh', 'Bash', guardCmd);

// --- Track old values for change reporting ---
const oldAutoMemory = settings.autoMemoryEnabled;
const oldAlwaysThinking = settings.alwaysThinkingEnabled;
const oldEffortLevel = settings.effortLevel;

// --- Merge claude preferences ---
settings.autoMemoryEnabled = autoMemory;
settings.alwaysThinkingEnabled = alwaysThinking;
if (effortLevel) settings.effortLevel = effortLevel;

// --- Detect preference changes ---
const prefChanges = [];
if (oldAutoMemory !== settings.autoMemoryEnabled) prefChanges.push('CHANGED: autoMemoryEnabled: ' + (oldAutoMemory !== undefined ? oldAutoMemory : '(not set)') + ' -> ' + settings.autoMemoryEnabled);
if (oldAlwaysThinking !== settings.alwaysThinkingEnabled) prefChanges.push('CHANGED: alwaysThinkingEnabled: ' + (oldAlwaysThinking !== undefined ? oldAlwaysThinking : '(not set)') + ' -> ' + settings.alwaysThinkingEnabled);
if (effortLevel && oldEffortLevel !== settings.effortLevel) prefChanges.push('CHANGED: effortLevel: ' + (oldEffortLevel || '(not set)') + ' -> ' + settings.effortLevel);

// --- Clobber detection ---
const managedKeys = ['hooks', 'autoMemoryEnabled', 'alwaysThinkingEnabled', 'effortLevel'];
const afterKeys = Object.keys(settings);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

if (dryRun) {
    console.error('[DRY RUN] ' + settingsFile + ': merge');
    console.error('  Managed fields: ' + managedKeys.join(', '));
    if (lostKeys.length > 0) console.error('  CLOBBER WARNING: would lose: ' + lostKeys.join(', '));
    if (corrupt) console.error('  File is corrupt -- --force required');
    console.error('  SessionEnd hook: ' + hookCmd);
    console.error('  PreToolUse hook: ' + guardCmd);
    console.error('  autoMemoryEnabled: ' + autoMemory);
    console.error('  alwaysThinkingEnabled: ' + alwaysThinking);
    if (effortLevel) console.error('  effortLevel: ' + effortLevel);
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
    const newJson = JSON.stringify(sortKeys(settings), null, 2) + '\n';
    let existingJson = '';
    try { existingJson = fs.readFileSync(settingsFile, 'utf8'); } catch(e) { /* file may not exist */ }
    const existingNorm = existingJson ? JSON.stringify(sortKeys(JSON.parse(existingJson))) : '';
    const mergedNorm = JSON.stringify(sortKeys(settings));
    if (mergedNorm === existingNorm) {
        console.log('unchanged');
    } else {
        fs.writeFileSync(settingsFile, newJson);

        // Post-write validation
        const _v = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
        const _required = ['hooks', 'autoMemoryEnabled', 'alwaysThinkingEnabled'];
        if (effortLevel) _required.push('effortLevel');
        const _missing = _required.filter(k => !(k in _v));
        if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }
        // Validate hook arrays have exactly one entry per managed hook
        const seCount = (_v.hooks.SessionEnd || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('session-archive.sh'))).length;
        const ptCount = (_v.hooks.PreToolUse || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('standing-order-guard.sh'))).length;
        if (seCount !== 1) { console.error('Validation failed: expected 1 SessionEnd hook, got ' + seCount); process.exit(1); }
        if (ptCount !== 1) { console.error('Validation failed: expected 1 PreToolUse hook, got ' + ptCount); process.exit(1); }

        console.log('ok');
        prefChanges.forEach(c => console.log(c));
    }
}
" "$SETTINGS_FILE" "$HOOK_CMD" "$GUARD_CMD" "$DRY_RUN" "$FORCE")

# Parse merge result: first line is status, CHANGED: lines are key changes
MERGE_STATUS=$(echo "$MERGE_RESULT" | head -1)

case "$MERGE_STATUS" in
    ok)
        log_ok "Settings deployed to $(display_path "$SETTINGS_FILE")"
        HOOKS_CHANGED=true
        log "  SessionEnd hook: $HOOK_CMD"
        log "  PreToolUse hook: $GUARD_CMD"
        log "  autoMemoryEnabled: $(node -e "console.log(JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8')).autoMemoryEnabled)")"
        log "  alwaysThinkingEnabled: $(node -e "console.log(JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8')).alwaysThinkingEnabled)")"
        log "  effortLevel: $(node -e "const s=JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8')); console.log(s.effortLevel || '(not set)')")"
        emit_merge_details "$MERGE_RESULT" "claude hooks"
        ;;
    unchanged)
        log_ok "Settings unchanged: $(display_path "$SETTINGS_FILE")"
        ;;
    dry-run)
        log "[DRY RUN] Would merge settings (see above)"
        ;;
    error-corrupt)
        log_error "$(display_path "$SETTINGS_FILE") is corrupt. Use --force to overwrite."
        write_summary ERROR "claude hooks" "settings corrupt"
        ;;
    error-clobber)
        log_error "$(display_path "$SETTINGS_FILE") merge would lose fields. Use --force to proceed."
        write_summary ERROR "claude hooks" "merge would lose fields"
        ;;
    *)
        log_error "Unexpected merge result: $MERGE_RESULT"
        write_summary ERROR "claude hooks" "unexpected error"
        ;;
esac

if [ "$ERRORS" -eq 0 ]; then
    if [ "$HOOKS_CHANGED" = "true" ]; then
        write_summary OK "claude hooks" "deployed"
    else
        write_summary OK "claude hooks" "unchanged"
    fi
fi
# --- END hooks body (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
# --- END exit (extracted by build-deploy) ---
