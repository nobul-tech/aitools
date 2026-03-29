#!/usr/bin/env bash
# setup-user-hooks.sh — Deploys Claude Code hooks and preferences to ~/.claude/settings.json
# Safe to re-run — merges managed fields without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop, autoMemoryEnabled, alwaysThinkingEnabled, effortLevel
# (includes delegation-duty-guard PreToolUse[Agent] hook,
#  harness-db-sessionstart/sessionend hooks with telemetry processing,
#  and Stop hooks for command channel and failure mode)
# Preserved: permissions, enabledPlugins, all other fields
#
# Hooks deployed:
#   SessionStart: scratch-init.sh (creates session scratch directory)
#   SessionStart: dashboard-serve.sh (launches live dashboard server)
#   SessionEnd: session-archive.sh (archives transcripts to user repo)
#   SessionEnd: harvest-session.sh (harvests session artifacts)
#   SessionEnd: tool-ops-session-audit.sh (runs tool-ops contract tests and drift detection)
#   PreToolUse[Bash]: standing-order-guard.sh (enforces standing orders on Bash commands)
#   PreToolUse[Read|Grep]: glossary-skill-guard.sh (reminds agent to use /glossary skill)
#   PreToolUse[Agent]: block-claude-code-guide.sh (blocks buggy built-in subagent)
#   PostToolUse[Write|Edit]: sh-file-fixup.sh (fixes CRLF and chmod on .sh files)
#   PreToolUse[Agent]: delegation-duty-guard.sh (checks delegation prompts for duty elements)
#   SessionStart: harness-db-sessionstart.sh (initializes harness SQLite DBs)
#   SessionEnd: harness-db-sessionend.sh (marks session complete, exports JSON)
#   Stop: command-channel-stop.sh (polls session DB for commander directives)
#   Stop: failure-mode-identity-stop.sh (reinforces agent identity and process)
#   Stop: failure-mode-verify-stop.sh (lightweight failure mode self-check)
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

# User repo for dotprofile overrides and adopt target
USER_REPO_PATH=$(read_config_key "$HOME/.aitools/config.json" "userRepoPath")
DOTPROFILE_HOOKS=""
if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH/claude/hooks" ]; then
    DOTPROFILE_HOOKS="$USER_REPO_PATH/claude/hooks"
fi

# Resolve hook source: dotprofile wins over shared
resolve_hook() {
    local hook_name="$1"
    if [ -n "$DOTPROFILE_HOOKS" ] && [ -f "$DOTPROFILE_HOOKS/$hook_name" ]; then
        printf '%s\n' "$DOTPROFILE_HOOKS/$hook_name"
    else
        printf '%s\n' "$REPO_DIR/shared/hooks/$hook_name"
    fi
}

HOOK_SCRIPT=$(resolve_hook "session-archive.sh")
GUARD_SCRIPT=$(resolve_hook "standing-order-guard.sh")
GLOSSARY_SCRIPT=$(resolve_hook "glossary-skill-guard.sh")
SCRATCH_SCRIPT=$(resolve_hook "scratch-init.sh")
HARVEST_SCRIPT=$(resolve_hook "harvest-session.sh")
SHFIXUP_SCRIPT=$(resolve_hook "sh-file-fixup.sh")
BLOCK_GUIDE_SCRIPT=$(resolve_hook "block-claude-code-guide.sh")
TOOL_OPS_AUDIT_SCRIPT=$(resolve_hook "tool-ops-session-audit.sh")
DASHBOARD_SCRIPT=$(resolve_hook "dashboard-serve.sh")
DELEG_GUARD_SCRIPT=$(resolve_hook "delegation-duty-guard.sh")
HARNESS_DB_START_SCRIPT=$(resolve_hook "harness-db-sessionstart.sh")
HARNESS_DB_END_SCRIPT=$(resolve_hook "harness-db-sessionend.sh")
CMD_CHANNEL_STOP_SCRIPT=$(resolve_hook "command-channel-stop.sh")
FM_IDENTITY_STOP_SCRIPT=$(resolve_hook "failure-mode-identity-stop.sh")
FM_VERIFY_STOP_SCRIPT=$(resolve_hook "failure-mode-verify-stop.sh")
for src in "$HOOK_SCRIPT" "$GUARD_SCRIPT" "$GLOSSARY_SCRIPT" "$SCRATCH_SCRIPT" "$HARVEST_SCRIPT" "$SHFIXUP_SCRIPT" "$BLOCK_GUIDE_SCRIPT" "$TOOL_OPS_AUDIT_SCRIPT" "$DASHBOARD_SCRIPT" "$DELEG_GUARD_SCRIPT" "$HARNESS_DB_START_SCRIPT" "$HARNESS_DB_END_SCRIPT" "$CMD_CHANNEL_STOP_SCRIPT" "$FM_IDENTITY_STOP_SCRIPT" "$FM_VERIFY_STOP_SCRIPT"; do
    if [ ! -f "$src" ]; then
        log_error "Hook script not found: $src"
        exit 1
    fi
done

# --- Deploy hook scripts to ~/.claude/hooks/ ---
HOOK_DEST="$HOME/.claude/hooks/session-archive.sh"
GUARD_DEST="$HOME/.claude/hooks/standing-order-guard.sh"
GLOSSARY_DEST="$HOME/.claude/hooks/glossary-skill-guard.sh"
SCRATCH_DEST="$HOME/.claude/hooks/scratch-init.sh"
HARVEST_DEST="$HOME/.claude/hooks/harvest-session.sh"
SHFIXUP_DEST="$HOME/.claude/hooks/sh-file-fixup.sh"
BLOCK_GUIDE_DEST="$HOME/.claude/hooks/block-claude-code-guide.sh"
TOOL_OPS_AUDIT_DEST="$HOME/.claude/hooks/tool-ops-session-audit.sh"
DASHBOARD_DEST="$HOME/.claude/hooks/dashboard-serve.sh"
DELEG_GUARD_DEST="$HOME/.claude/hooks/delegation-duty-guard.sh"
HARNESS_DB_START_DEST="$HOME/.claude/hooks/harness-db-sessionstart.sh"
HARNESS_DB_END_DEST="$HOME/.claude/hooks/harness-db-sessionend.sh"
CMD_CHANNEL_STOP_DEST="$HOME/.claude/hooks/command-channel-stop.sh"
FM_IDENTITY_STOP_DEST="$HOME/.claude/hooks/failure-mode-identity-stop.sh"
FM_VERIFY_STOP_DEST="$HOME/.claude/hooks/failure-mode-verify-stop.sh"

HOOKS_CHANGED=false

_hook_adopt_label=""
if [ -n "$USER_REPO_PATH" ]; then _hook_adopt_label="dotprofile"; fi

if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would deploy hook: $(display_path "$HOOK_SCRIPT") -> $(display_path "$HOOK_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$GUARD_SCRIPT") -> $(display_path "$GUARD_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$GLOSSARY_SCRIPT") -> $(display_path "$GLOSSARY_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$SCRATCH_SCRIPT") -> $(display_path "$SCRATCH_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$HARVEST_SCRIPT") -> $(display_path "$HARVEST_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$SHFIXUP_SCRIPT") -> $(display_path "$SHFIXUP_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$BLOCK_GUIDE_SCRIPT") -> $(display_path "$BLOCK_GUIDE_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$TOOL_OPS_AUDIT_SCRIPT") -> $(display_path "$TOOL_OPS_AUDIT_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$DASHBOARD_SCRIPT") -> $(display_path "$DASHBOARD_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$DELEG_GUARD_SCRIPT") -> $(display_path "$DELEG_GUARD_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$HARNESS_DB_START_SCRIPT") -> $(display_path "$HARNESS_DB_START_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$HARNESS_DB_END_SCRIPT") -> $(display_path "$HARNESS_DB_END_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$CMD_CHANNEL_STOP_SCRIPT") -> $(display_path "$CMD_CHANNEL_STOP_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$FM_IDENTITY_STOP_SCRIPT") -> $(display_path "$FM_IDENTITY_STOP_DEST")"
    log "[DRY RUN] Would deploy hook: $(display_path "$FM_VERIFY_STOP_SCRIPT") -> $(display_path "$FM_VERIFY_STOP_DEST")"
    # Stale hook cleanup preview
    for stale_hook in surfacing-duty-stop.sh estimate-refresh-stop.sh intent-sentinel-stop.sh; do
        if [ -f "$HOME/.claude/hooks/$stale_hook" ]; then
            log "[DRY RUN] Would remove stale hook: $stale_hook"
        fi
    done
else
    mkdir -p "$HOME/.claude/hooks"

    deploy_tracker_init

    for hook_pair in "$HOOK_SCRIPT|$HOOK_DEST" "$GUARD_SCRIPT|$GUARD_DEST" "$GLOSSARY_SCRIPT|$GLOSSARY_DEST" "$SCRATCH_SCRIPT|$SCRATCH_DEST" "$HARVEST_SCRIPT|$HARVEST_DEST" "$SHFIXUP_SCRIPT|$SHFIXUP_DEST" "$BLOCK_GUIDE_SCRIPT|$BLOCK_GUIDE_DEST" "$TOOL_OPS_AUDIT_SCRIPT|$TOOL_OPS_AUDIT_DEST" "$DASHBOARD_SCRIPT|$DASHBOARD_DEST" "$DELEG_GUARD_SCRIPT|$DELEG_GUARD_DEST" "$HARNESS_DB_START_SCRIPT|$HARNESS_DB_START_DEST" "$HARNESS_DB_END_SCRIPT|$HARNESS_DB_END_DEST" "$CMD_CHANNEL_STOP_SCRIPT|$CMD_CHANNEL_STOP_DEST" "$FM_IDENTITY_STOP_SCRIPT|$FM_IDENTITY_STOP_DEST" "$FM_VERIFY_STOP_SCRIPT|$FM_VERIFY_STOP_DEST"; do
        hook_src="${hook_pair%%|*}"
        hook_dst="${hook_pair##*|}"
        hook_name=$(basename "$hook_dst")

        deploy_managed_file "$(cat "$hook_src")" "$hook_dst" "claude hooks" "$hook_name" "$_hook_adopt_label"

        case "$MANAGED_FILE_RESULT" in
            "accept & adopt")
                if [ -n "$USER_REPO_PATH" ]; then
                    mkdir -p "$USER_REPO_PATH/claude/hooks"
                    cp "$hook_dst" "$USER_REPO_PATH/claude/hooks/$hook_name"
                    log_ok "Adopted hook to dotprofile: $hook_name"
                    if [ -c /dev/tty ]; then
                        printf '  Review: cd %s && git diff\n' \
                            "$(display_path "$USER_REPO_PATH")" > /dev/tty
                    fi
                else
                    log_warn "Cannot adopt: no user repo configured (run 'aitools user init')"
                fi
                ;;
            created|updated)
                chmod +x "$hook_dst"
                HOOKS_CHANGED=true
                ;;
            skipped|verified)
                ;;
        esac
        deploy_tracker_record "$MANAGED_FILE_RESULT" "claude hooks" "$hook_name"
    done

    deploy_tracker_summary "claude hooks"

    # --- Stale hook cleanup ---
    # Remove hook files that were previously deployed but are no longer managed.
    # These were removed from shared/hooks/ in commit e070043 but remain on disk.
    STALE_HOOKS="surfacing-duty-stop.sh estimate-refresh-stop.sh intent-sentinel-stop.sh"
    for stale_hook in $STALE_HOOKS; do
        stale_path="$HOME/.claude/hooks/$stale_hook"
        if [ -f "$stale_path" ]; then
            rm -f "$stale_path"
            log_ok "Removed stale hook: $stale_hook"
            HOOKS_CHANGED=true
        fi
        # Also remove any backups of stale hooks
        for bak in "$HOME/.claude/hooks/${stale_hook}.bak."*; do
            if [ -f "$bak" ]; then
                rm -f "$bak"
                log "Removed stale backup: $(basename "$bak")"
            fi
        done
    done

    # --- Reverse discovery ---
    # Scan deployed hooks for user-created hooks not in shared or dotprofile
    for hook_file in "$HOME/.claude/hooks"/*.sh; do
        [ -f "$hook_file" ] || continue
        hook_name=$(basename "$hook_file")

        # Skip if in shared
        [ -f "$REPO_DIR/shared/hooks/$hook_name" ] && continue
        # Skip if in dotprofile
        if [ -n "$DOTPROFILE_HOOKS" ] && [ -f "$DOTPROFILE_HOOKS/$hook_name" ]; then
            continue
        fi

        # Found a user-created hook
        if [ -n "$USER_REPO_PATH" ]; then
            log "Found user-created hook: $hook_name"
            if [ -c /dev/tty ]; then
                printf '\n  User-created hook detected: %s\n' "$hook_name" > /dev/tty
                printf '  [a]dopt to dotprofile  [s]kip\n' > /dev/tty
                printf '  > ' > /dev/tty
                choice=""
                read -r choice < /dev/tty
                case "$choice" in
                    a|adopt)
                        mkdir -p "$USER_REPO_PATH/claude/hooks"
                        cp "$hook_file" "$USER_REPO_PATH/claude/hooks/$hook_name"
                        log_ok "Adopted user hook to dotprofile: $hook_name"
                        ;;
                    *)
                        log "Skipped adoption of $hook_name"
                        ;;
                esac
            fi
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
GLOSSARY_CMD="bash \"$HOME/.claude/hooks/glossary-skill-guard.sh\""
SCRATCH_CMD="bash \"$SCRATCH_DEST\""
HARVEST_CMD="bash \"$HARVEST_DEST\""
SHFIXUP_CMD="bash \"$SHFIXUP_DEST\""
BLOCK_GUIDE_CMD="bash \"$BLOCK_GUIDE_DEST\""
TOOL_OPS_AUDIT_CMD="bash \"$TOOL_OPS_AUDIT_DEST\""
DASHBOARD_CMD="bash \"$DASHBOARD_DEST\""
DELEG_GUARD_CMD="bash \"$DELEG_GUARD_DEST\""
HARNESS_DB_START_CMD="bash \"$HARNESS_DB_START_DEST\""
HARNESS_DB_END_CMD="bash \"$HARNESS_DB_END_DEST\""
CMD_CHANNEL_STOP_CMD="bash \"$CMD_CHANNEL_STOP_DEST\""
FM_IDENTITY_STOP_CMD="bash \"$FM_IDENTITY_STOP_DEST\""
FM_VERIFY_STOP_CMD="bash \"$FM_VERIFY_STOP_DEST\""

MERGE_RESULT=$(node -e "
$SORT_KEYS_JS
const fs = require('fs');
const path = require('path');
const settingsFile = process.argv[1];
const hookCmd = process.argv[2];
const guardCmd = process.argv[3];
const glossaryCmd = process.argv[4];
const dryRun = process.argv[5] === 'true';
const force = process.argv[6] === 'true';
const scratchCmd = process.argv[7];
const harvestCmd = process.argv[8];
const shfixupCmd = process.argv[9];
const blockGuideCmd = process.argv[10];
const toolOpsAuditCmd = process.argv[11];
const dashboardCmd = process.argv[12];
const delegGuardCmd = process.argv[13];
const harnessDbStartCmd = process.argv[14];
const harnessDbEndCmd = process.argv[15];
const cmdChannelStopCmd = process.argv[16];
const fmIdentityStopCmd = process.argv[17];
const fmVerifyStopCmd = process.argv[18];

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
function mergeHookEntry(eventName, hookId, matcher, cmd, hookType) {
    hookType = hookType || 'command';
    if (!Array.isArray(settings.hooks[eventName])) settings.hooks[eventName] = [];
    const arr = settings.hooks[eventName];

    // Find first matching entry and update it
    let found = false;
    for (const rule of arr) {
        if (rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId))) {
            if (!found) {
                rule.hooks.forEach(h => {
                    if (h.command && h.command.includes(hookId)) {
                        h.command = cmd;
                        h.type = hookType;
                    }
                });
                rule.matcher = matcher;
                found = true;
            }
        }
    }
    if (!found) {
        arr.push({ matcher, hooks: [{ type: hookType, command: cmd }] });
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

// Helper: remove all entries for a hookId from an event array.
// Used to clean up stale hook registrations after hooks are deleted.
function removeHookEntry(eventName, hookId) {
    if (!Array.isArray(settings.hooks[eventName])) return;
    settings.hooks[eventName] = settings.hooks[eventName].filter(rule => {
        return !(rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId)));
    });
    // Remove the event key entirely if empty
    if (settings.hooks[eventName].length === 0) {
        delete settings.hooks[eventName];
    }
}

// Remove stale Stop hooks (deleted from shared/hooks/ in commit e070043)
removeHookEntry('Stop', 'surfacing-duty-stop.sh');
removeHookEntry('Stop', 'estimate-refresh-stop.sh');
removeHookEntry('Stop', 'intent-sentinel-stop.sh');

mergeHookEntry('SessionEnd', 'session-archive.sh', '', hookCmd);
mergeHookEntry('SessionEnd', 'harvest-session.sh', '', harvestCmd);
mergeHookEntry('SessionStart', 'scratch-init.sh', '', scratchCmd);
mergeHookEntry('PreToolUse', 'standing-order-guard.sh', 'Bash', guardCmd);
mergeHookEntry('PreToolUse', 'glossary-skill-guard.sh', 'Read|Grep', glossaryCmd);
mergeHookEntry('PostToolUse', 'sh-file-fixup.sh', 'Write|Edit', shfixupCmd);
mergeHookEntry('PreToolUse', 'block-claude-code-guide.sh', 'Agent', blockGuideCmd);
mergeHookEntry('SessionEnd', 'tool-ops-session-audit.sh', '', toolOpsAuditCmd);
mergeHookEntry('SessionStart', 'dashboard-serve.sh', '', dashboardCmd);
mergeHookEntry('PreToolUse', 'delegation-duty-guard.sh', 'Agent', delegGuardCmd);
mergeHookEntry('SessionStart', 'harness-db-sessionstart.sh', '', harnessDbStartCmd);
mergeHookEntry('SessionEnd', 'harness-db-sessionend.sh', '', harnessDbEndCmd);
mergeHookEntry('Stop', 'command-channel-stop.sh', '', cmdChannelStopCmd);
mergeHookEntry('Stop', 'failure-mode-identity-stop.sh', '', fmIdentityStopCmd);
mergeHookEntry('Stop', 'failure-mode-verify-stop.sh', '', fmVerifyStopCmd);

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
        const seArchiveCount = (_v.hooks.SessionEnd || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('session-archive.sh'))).length;
        const seHarvestCount = (_v.hooks.SessionEnd || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('harvest-session.sh'))).length;
        const ssCount = (_v.hooks.SessionStart || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('scratch-init.sh'))).length;
        const ptCount = (_v.hooks.PreToolUse || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('standing-order-guard.sh'))).length;
        if (seArchiveCount !== 1) { console.error('Validation failed: expected 1 SessionEnd session-archive hook, got ' + seArchiveCount); process.exit(1); }
        if (seHarvestCount !== 1) { console.error('Validation failed: expected 1 SessionEnd harvest-session hook, got ' + seHarvestCount); process.exit(1); }
        if (ssCount !== 1) { console.error('Validation failed: expected 1 SessionStart scratch-init hook, got ' + ssCount); process.exit(1); }
        if (ptCount !== 1) { console.error('Validation failed: expected 1 PreToolUse standing-order-guard hook, got ' + ptCount); process.exit(1); }
        const glCount = (_v.hooks.PreToolUse || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('glossary-skill-guard.sh'))).length;
        if (glCount !== 1) { console.error('Validation failed: expected 1 PreToolUse glossary-skill-guard hook, got ' + glCount); process.exit(1); }
        const bgCount = (_v.hooks.PreToolUse || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('block-claude-code-guide.sh'))).length;
        if (bgCount !== 1) { console.error('Validation failed: expected 1 PreToolUse block-claude-code-guide hook, got ' + bgCount); process.exit(1); }
        const toaCount = (_v.hooks.SessionEnd || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('tool-ops-session-audit.sh'))).length;
        if (toaCount !== 1) { console.error('Validation failed: expected 1 SessionEnd tool-ops-session-audit hook, got ' + toaCount); process.exit(1); }
        const dashCount = (_v.hooks.SessionStart || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('dashboard-serve.sh'))).length;
        if (dashCount !== 1) { console.error('Validation failed: expected 1 SessionStart dashboard-serve hook, got ' + dashCount); process.exit(1); }
        const dgCount = (_v.hooks.PreToolUse || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('delegation-duty-guard.sh'))).length;
        if (dgCount !== 1) { console.error('Validation failed: expected 1 PreToolUse delegation-duty-guard hook, got ' + dgCount); process.exit(1); }
        const hdbStartCount = (_v.hooks.SessionStart || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('harness-db-sessionstart.sh'))).length;
        if (hdbStartCount !== 1) { console.error('Validation failed: expected 1 SessionStart harness-db-sessionstart hook, got ' + hdbStartCount); process.exit(1); }
        const hdbEndCount = (_v.hooks.SessionEnd || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('harness-db-sessionend.sh'))).length;
        if (hdbEndCount !== 1) { console.error('Validation failed: expected 1 SessionEnd harness-db-sessionend hook, got ' + hdbEndCount); process.exit(1); }
        const ccStopCount = (_v.hooks.Stop || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('command-channel-stop.sh'))).length;
        if (ccStopCount !== 1) { console.error('Validation failed: expected 1 Stop command-channel-stop hook, got ' + ccStopCount); process.exit(1); }
        const fmiStopCount = (_v.hooks.Stop || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('failure-mode-identity-stop.sh'))).length;
        if (fmiStopCount !== 1) { console.error('Validation failed: expected 1 Stop failure-mode-identity-stop hook, got ' + fmiStopCount); process.exit(1); }
        const fmvStopCount = (_v.hooks.Stop || []).filter(r => r.hooks && r.hooks.some(h => h.command && h.command.includes('failure-mode-verify-stop.sh'))).length;
        if (fmvStopCount !== 1) { console.error('Validation failed: expected 1 Stop failure-mode-verify-stop hook, got ' + fmvStopCount); process.exit(1); }

        // Validate hook schema: command-type must have command field,
        // prompt-type must have prompt field (not command).
        // Catches the type mismatch that broke settings.json in v0.60.
        for (const [event, rules] of Object.entries(_v.hooks || {})) {
            for (const rule of (rules || [])) {
                for (const h of (rule.hooks || [])) {
                    if (h.type === 'command' && !h.command) {
                        console.error('Validation failed: ' + event + ' hook has type "command" but no command field');
                        process.exit(1);
                    }
                    if (h.type === 'prompt') {
                        if (!h.prompt) {
                            console.error('Validation failed: ' + event + ' hook has type "prompt" but no prompt field. Prompt-type hooks require a static string in the prompt field, not a command path.');
                            process.exit(1);
                        }
                        if (h.command) {
                            console.error('Validation failed: ' + event + ' hook has type "prompt" with a command field. Prompt-type hooks use the prompt field for static text. Use type "command" for script execution.');
                            process.exit(1);
                        }
                    }
                }
            }
        }

        console.log('ok');
        prefChanges.forEach(c => console.log(c));
    }
}
" "$SETTINGS_FILE" "$HOOK_CMD" "$GUARD_CMD" "$GLOSSARY_CMD" "$DRY_RUN" "$FORCE" "$SCRATCH_CMD" "$HARVEST_CMD" "$SHFIXUP_CMD" "$BLOCK_GUIDE_CMD" "$TOOL_OPS_AUDIT_CMD" "$DASHBOARD_CMD" "$DELEG_GUARD_CMD" "$HARNESS_DB_START_CMD" "$HARNESS_DB_END_CMD" "$CMD_CHANNEL_STOP_CMD" "$FM_IDENTITY_STOP_CMD" "$FM_VERIFY_STOP_CMD")

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
