#!/usr/bin/env bash
# setup-user-hooks.sh — Deploys Claude Code hooks to ~/.claude/settings.json
# Safe to re-run — merges the `hooks` key without clobbering existing settings.
#
# Hook deployment + registration are GENERATED from shared/hooks/hooks-manifest.json
# (the single source of truth). Adding a hook = one manifest entry; no edits to this
# script. This closes the recurring "deployed but not registered" / parallel-list-drift
# incident class (RCA: .scratch investigation 2026-06-20; issue #7 / plan §5).
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop
# Preserved: permissions, enabledPlugins, all other fields
#
# Claude preferences (autoMemoryEnabled/alwaysThinkingEnabled/effortLevel) and all
# other non-hook settings are profile-sourced and synced by setup-user-settings.
# See reference/user-repo.md, shared/hooks/hooks-manifest.json, and shared/hooks/ for details.

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
# --- Resolve repo path + manifest ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Manifest = single source of truth for which hooks exist + how they register.
MANIFEST="$REPO_DIR/shared/hooks/hooks-manifest.json"
if [ ! -f "$MANIFEST" ]; then
    log_error "Hook manifest not found: $MANIFEST"
    exit 1
fi

# User repo for dotprofile overrides and adopt target.
# `|| true`: key is absent until 'aitools user init' runs; without the guard,
# set -e silently aborts before falling back to shared-only hooks.
USER_REPO_PATH=$(read_config_key "$HOME/.aitools/config.json" "userRepoPath") || true
DOTPROFILE_HOOKS=""
if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH/claude/hooks" ]; then
    DOTPROFILE_HOOKS="$USER_REPO_PATH/claude/hooks"
fi

# Resolve hook source: dotprofile wins over shared/hooks, then scripts/ (for
# deploy-only .py helpers like ait-harvest.py that live in scripts/).
resolve_hook() {
    local hook_name="$1"
    if [ -n "$DOTPROFILE_HOOKS" ] && [ -f "$DOTPROFILE_HOOKS/$hook_name" ]; then
        printf '%s\n' "$DOTPROFILE_HOOKS/$hook_name"
    elif [ -f "$REPO_DIR/shared/hooks/$hook_name" ]; then
        printf '%s\n' "$REPO_DIR/shared/hooks/$hook_name"
    elif [ -f "$REPO_DIR/scripts/$hook_name" ]; then
        printf '%s\n' "$REPO_DIR/scripts/$hook_name"
    else
        printf '%s\n' "$REPO_DIR/shared/hooks/$hook_name"
    fi
}

# Files to deploy = registered hooks + deploy-only helpers, from the manifest.
HOOK_FILES=()
while IFS= read -r _f; do
    [ -n "$_f" ] && HOOK_FILES+=("$_f")
done < <(node -e '
const fs = require("fs");
const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const files = [...m.hooks.map(h => h.file), ...((m.deploy) || [])];
console.log(files.join("\n"));
' "$MANIFEST")

if [ "${#HOOK_FILES[@]}" -eq 0 ]; then
    log_error "Manifest produced no hook files -- aborting"
    exit 1
fi

# Registration list (event/file/matcher) from the manifest -- passed to the node
# merge block as an argv. build-deploy embeds this statically for the
# self-contained MDM path, so the node block is identical dev and deploy.
REGS_JSON=$(node -e '
const fs = require("fs");
const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
console.log(JSON.stringify(m.hooks.map(h => ({event: h.event, file: h.file, matcher: h.matcher || ""}))));
' "$MANIFEST")
if [ -z "$REGS_JSON" ]; then
    log_error "Failed to build registration list from manifest"
    exit 1
fi

# Existence check (resolve every manifest file before deploying any).
for hook_name in "${HOOK_FILES[@]}"; do
    src=$(resolve_hook "$hook_name")
    if [ ! -f "$src" ]; then
        log_error "Hook script not found: $src"
        exit 1
    fi
done

_hook_adopt_label=""
if [ -n "$USER_REPO_PATH" ]; then _hook_adopt_label="dotprofile"; fi

HOOKS_CHANGED=false

if [ "$DRY_RUN" = "true" ]; then
    for hook_name in "${HOOK_FILES[@]}"; do
        src=$(resolve_hook "$hook_name")
        log "[DRY RUN] Would deploy hook: $(display_path "$src") -> $(display_path "$HOME/.claude/hooks/$hook_name")"
    done
    # Stale hook cleanup preview
    for stale_hook in surfacing-duty-stop.sh estimate-refresh-stop.sh intent-sentinel-stop.sh; do
        if [ -f "$HOME/.claude/hooks/$stale_hook" ]; then
            log "[DRY RUN] Would remove stale hook: $stale_hook"
        fi
    done
else
    mkdir -p "$HOME/.claude/hooks"

    deploy_tracker_init

    for hook_name in "${HOOK_FILES[@]}"; do
        hook_src=$(resolve_hook "$hook_name")
        hook_dst="$HOME/.claude/hooks/$hook_name"

        deploy_managed_file "$(cat "$hook_src")" "$hook_dst" "claude hooks" "$hook_name" "$_hook_adopt_label"

        case "$MANAGED_FILE_RESULT" in
            "accept & adopt")
                # Adopt: deployed (local) wins -> write back to BOTH canonical
                # sources via adopt_managed_file (rotated backups + copy + log).
                # Hooks deploy verbatim, so shared/ + dotprofile each get a
                # straight copy. shared/hooks is absent in MDM deploys; dotprofile
                # is absent when no user repo is configured -- empty targets skip.
                _adopt_targets=()
                [ -d "$REPO_DIR/shared/hooks" ] && _adopt_targets+=("$REPO_DIR/shared/hooks/$hook_name")
                [ -n "$USER_REPO_PATH" ] && _adopt_targets+=("$USER_REPO_PATH/claude/hooks/$hook_name")
                if [ "${#_adopt_targets[@]}" -gt 0 ]; then
                    adopt_managed_file "$hook_dst" "${_adopt_targets[@]}"
                    if [ -n "$USER_REPO_PATH" ] && [ -c /dev/tty ]; then
                        printf '  Review: cd %s && git diff\n' \
                            "$(display_path "$USER_REPO_PATH")" > /dev/tty
                    fi
                else
                    log_warn "Cannot adopt: no shared/ or user repo target (run 'aitools user init')"
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
    # Remove hook files previously deployed but no longer managed (deleted from
    # shared/hooks/ in commit e070043). Registration cleanup is handled in the
    # node merge block via removeHookEntry.
    STALE_HOOKS="surfacing-duty-stop.sh estimate-refresh-stop.sh intent-sentinel-stop.sh"
    for stale_hook in $STALE_HOOKS; do
        stale_path="$HOME/.claude/hooks/$stale_hook"
        if [ -f "$stale_path" ]; then
            rm -f "$stale_path"
            log_ok "Removed stale hook: $stale_hook"
            HOOKS_CHANGED=true
        fi
        for bak in "$HOME/.claude/hooks/${stale_hook}.bak."*; do
            if [ -f "$bak" ]; then
                rm -f "$bak"
                log "Removed stale backup: $(basename "$bak")"
            fi
        done
    done

    # --- Reverse discovery ---
    # Scan deployed hooks for user-created hooks not in shared or dotprofile.
    for hook_file in "$HOME/.claude/hooks"/*.sh; do
        [ -f "$hook_file" ] || continue
        hook_name=$(basename "$hook_file")

        [ -f "$REPO_DIR/shared/hooks/$hook_name" ] && continue
        if [ -n "$DOTPROFILE_HOOKS" ] && [ -f "$DOTPROFILE_HOOKS/$hook_name" ]; then
            continue
        fi

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
                        # Net-new user hook -> dotprofile only (not a managed
                        # shared/ hook). Same helper for consistent backups.
                        adopt_managed_file "$hook_file" "$USER_REPO_PATH/claude/hooks/$hook_name"
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

# --- Merge hooks + preferences into ~/.claude/settings.json ---
# Registrations are GENERATED from the manifest (event, file, matcher) -- the node
# block loops mergeHookEntry + validation over every manifest entry. No per-hook
# *_CMD vars or positional argv.
SETTINGS_FILE="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"

MERGE_RESULT=$(node -e "
$SORT_KEYS_JS
const fs = require('fs');
const path = require('path');
const settingsFile = process.argv[1];
const regsJson = process.argv[2];
const dryRun = process.argv[3] === 'true';
const force = process.argv[4] === 'true';
const home = process.env.HOME || process.env.USERPROFILE;

// --- Registrations from the manifest (computed in bash -> REGS_JSON argv) ---
const regs = JSON.parse(regsJson).map(r => ({
    event: r.event,
    hookId: r.file,
    matcher: r.matcher || '',
    cmd: 'bash \"' + path.join(home, '.claude', 'hooks', r.file) + '\"'
}));

// Claude preferences (autoMemoryEnabled / alwaysThinkingEnabled / effortLevel)
// are NOT managed here -- they are profile-sourced and synced by
// setup-user-settings. This script manages only the \`hooks\` key.

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

// Ensure exactly one entry for a hookId in an event array (update/add/dedupe).
function mergeHookEntry(eventName, hookId, matcher, cmd, hookType) {
    hookType = hookType || 'command';
    if (!Array.isArray(settings.hooks[eventName])) settings.hooks[eventName] = [];
    const arr = settings.hooks[eventName];
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

// Remove all entries for a hookId from an event array.
function removeHookEntry(eventName, hookId) {
    if (!Array.isArray(settings.hooks[eventName])) return;
    settings.hooks[eventName] = settings.hooks[eventName].filter(rule => {
        return !(rule.hooks && rule.hooks.some(h => h.command && h.command.includes(hookId)));
    });
    if (settings.hooks[eventName].length === 0) {
        delete settings.hooks[eventName];
    }
}

// Remove stale hooks (deleted from shared/hooks/ in commit e070043).
removeHookEntry('Stop', 'surfacing-duty-stop.sh');
removeHookEntry('Stop', 'estimate-refresh-stop.sh');
removeHookEntry('Stop', 'intent-sentinel-stop.sh');

// Register every manifest hook (generated -- no hardcoded list).
for (const r of regs) mergeHookEntry(r.event, r.hookId, r.matcher, r.cmd);

// --- Clobber detection ---
const managedKeys = ['hooks'];
const afterKeys = Object.keys(settings);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

if (dryRun) {
    console.error('[DRY RUN] ' + settingsFile + ': merge');
    console.error('  Managed fields: ' + managedKeys.join(', '));
    if (lostKeys.length > 0) console.error('  CLOBBER WARNING: would lose: ' + lostKeys.join(', '));
    if (corrupt) console.error('  File is corrupt -- --force required');
    console.error('  Registered hooks: ' + regs.length);
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
    // Preserve key order on write (no sort); sortKeys is used only for the
    // order-independent unchanged comparison so reordering alone never rewrites.
    const newJson = JSON.stringify(settings, null, 2) + '\n';
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
        const _required = ['hooks'];
        const _missing = _required.filter(k => !(k in _v));
        if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }

        // Validate: every manifest hook registered exactly once (generated check).
        for (const r of regs) {
            const c = (_v.hooks[r.event] || []).filter(rule => rule.hooks && rule.hooks.some(h => h.command && h.command.includes(r.hookId))).length;
            if (c !== 1) { console.error('Validation failed: expected 1 ' + r.event + ' ' + r.hookId + ' hook, got ' + c); process.exit(1); }
        }

        // Validate hook schema: command-type must have command field,
        // prompt-type must have prompt field (not command). (v0.60 incident guard.)
        for (const [event, rules] of Object.entries(_v.hooks || {})) {
            for (const rule of (rules || [])) {
                for (const h of (rule.hooks || [])) {
                    if (h.type === 'command' && !h.command) {
                        console.error('Validation failed: ' + event + ' hook has type \"command\" but no command field');
                        process.exit(1);
                    }
                    if (h.type === 'prompt') {
                        if (!h.prompt) {
                            console.error('Validation failed: ' + event + ' hook has type \"prompt\" but no prompt field.');
                            process.exit(1);
                        }
                        if (h.command) {
                            console.error('Validation failed: ' + event + ' hook has type \"prompt\" with a command field.');
                            process.exit(1);
                        }
                    }
                }
            }
        }

        console.log('ok');
    }
}
" "$SETTINGS_FILE" "$REGS_JSON" "$DRY_RUN" "$FORCE")

# Parse merge result: first line is status, CHANGED: lines are key changes
MERGE_STATUS=$(echo "$MERGE_RESULT" | head -1)

case "$MERGE_STATUS" in
    ok)
        log_ok "Hooks deployed to $(display_path "$SETTINGS_FILE")"
        HOOKS_CHANGED=true
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
