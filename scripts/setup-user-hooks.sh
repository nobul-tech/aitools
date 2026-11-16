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
    write_error "claude hooks" "hooks not deployed" "node not found (run aitools install)"
    exit 1
fi

# --- BEGIN hook deployment (replaced by build-deploy) ---
# --- Resolve repo path + manifest ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Manifest = single source of truth for which hooks exist + how they register.
MANIFEST="$REPO_DIR/shared/hooks/hooks-manifest.json"
if [ ! -f "$MANIFEST" ]; then
    write_error "claude hooks" "hooks not deployed" "hook manifest not found: $MANIFEST"
    exit 1
fi

# node's stderr for the manifest reads goes to a temp file (stdout is the data),
# so a failed read carries its reason (reference/logging.md 8.3).
MANIFEST_ERR=""
# 2>/dev/null: a mktemp failure is checked on the next line (fallback /dev/null)
if ! MANIFEST_ERR=$(mktemp 2>/dev/null); then MANIFEST_ERR=""; fi
if [ -z "$MANIFEST_ERR" ] || [ ! -f "$MANIFEST_ERR" ]; then
    log_detail "mktemp failed -- node's stderr for the manifest reads is not captured"
    MANIFEST_ERR=/dev/null
fi
# manifest_err_text -- print what node wrote to stderr (nothing when not captured)
manifest_err_text() {
    if [ "$MANIFEST_ERR" != "/dev/null" ]; then printf '%s' "$(<"$MANIFEST_ERR")"; fi
}
# manifest_fail WHAT RC -- record a failed manifest read with node's stderr as its
# reason, remove the temp file and end the script with status 1
manifest_fail() {
    local reason
    reason=$(error_reason "$(manifest_err_text)" "$2")
    if [ "$MANIFEST_ERR" != "/dev/null" ]; then rm -f "$MANIFEST_ERR"; fi
    write_error "claude hooks" "$1" "$reason"
    exit 1
}

# User repo: home of user-created (non-manifest) hooks only (SD-2, incident #80).
# Manifest hooks have one version, in shared/hooks; a dotprofile copy is never
# deployed (it would freeze the hook on this machine and diverge from the MDM
# path, which embeds shared/hooks only).
# `|| true`: key is absent until 'aitools user init' runs; without the guard,
# set -e silently aborts. An empty result is handled below (no dotprofile).
USER_REPO_PATH=$(read_config_key "$HOME/.aitools/config.json" "userRepoPath") || true
DOTPROFILE_HOOKS=""
if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH/claude/hooks" ]; then
    DOTPROFILE_HOOKS="$USER_REPO_PATH/claude/hooks"
fi

# Resolve hook source: shared/hooks, then scripts/ (for deploy-only .py helpers
# like ait-harvest.py that live in scripts/). Same order as build-deploy.sh's
# embed loops, so the dev and MDM paths deploy the same file.
resolve_hook() {
    local hook_name="$1"
    if [ -f "$REPO_DIR/shared/hooks/$hook_name" ]; then
        printf '%s\n' "$REPO_DIR/shared/hooks/$hook_name"
    elif [ -f "$REPO_DIR/scripts/$hook_name" ]; then
        printf '%s\n' "$REPO_DIR/scripts/$hook_name"
    else
        printf '%s\n' "$REPO_DIR/shared/hooks/$hook_name"
    fi
}

# Files to deploy = registered hooks + deploy-only helpers, from the manifest.
# Captured with its exit code (a process substitution would lose a failed read).
list_rc=0
HOOK_LIST=$(node -e '
const fs = require("fs");
const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const files = [...m.hooks.map(h => h.file), ...((m.deploy) || [])];
console.log(files.join("\n"));
' "$MANIFEST" 2>"$MANIFEST_ERR") || list_rc=$?
if [ "$list_rc" -ne 0 ]; then manifest_fail "hook manifest unreadable" "$list_rc"; fi
HOOK_FILES=()
while IFS= read -r _f; do
    if [ -n "$_f" ]; then HOOK_FILES+=("$_f"); fi
done <<< "$HOOK_LIST"

if [ "${#HOOK_FILES[@]}" -eq 0 ]; then
    if [ "$MANIFEST_ERR" != "/dev/null" ]; then rm -f "$MANIFEST_ERR"; fi
    write_error "claude hooks" "hooks not deployed" "manifest lists no hooks"
    exit 1
fi

# Registration list (event/file/matcher) from the manifest -- passed to the node
# merge block as an argv. build-deploy embeds this statically for the
# self-contained MDM path, so the node block is identical dev and deploy.
# The exit code is captured (a bare assignment would abort under set -e with no row).
regs_rc=0
REGS_JSON=$(node -e '
const fs = require("fs");
const m = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
console.log(JSON.stringify(m.hooks.map(h => ({event: h.event, file: h.file, matcher: h.matcher || ""}))));
' "$MANIFEST" 2>"$MANIFEST_ERR") || regs_rc=$?
if [ "$regs_rc" -ne 0 ] || [ -z "$REGS_JSON" ]; then
    # An empty list with exit 0 gives the reason "no output (exit 0)"
    manifest_fail "registration list not built" "$regs_rc"
fi
if [ "$MANIFEST_ERR" != "/dev/null" ]; then rm -f "$MANIFEST_ERR"; fi

# Existence check (resolve every manifest file before deploying any).
for hook_name in "${HOOK_FILES[@]}"; do
    src=$(resolve_hook "$hook_name")
    if [ ! -f "$src" ]; then
        write_error "claude hooks" "hooks not deployed" "hook script not found: $src"
        exit 1
    fi
    # A dotprofile copy of a manifest hook is ignored (SD-2): say so, so the
    # user can delete it instead of believing their edit is live. One warning
    # per copy, named.
    if [ -n "$DOTPROFILE_HOOKS" ] && [ -f "$DOTPROFILE_HOOKS/$hook_name" ]; then
        write_warn "claude hooks" "dotprofile copy of $hook_name ignored -- delete $(display_path "$DOTPROFILE_HOOKS/$hook_name")"
    fi
done

# Adopt target for manifest hooks: the file the hook is deployed from --
# shared/hooks/<name>, or scripts/<name> for deploy-only helpers (resolve_hook).
# Never the dotprofile (SD-2, incident #80). The library writes it.


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

        deploy_managed_file "$(cat "$hook_src")" "$hook_dst" "claude hooks" "$hook_name" "$hook_src"

        case "$MANAGED_FILE_RESULT" in
            created|updated|"accept & adopt")
                # accept & adopt: the library also wrote the source file in the
                # repo; a merge rewrote the deployed hook, so keep it executable.
                ch_rc=0
                ch_out=$(chmod +x "$hook_dst" 2>&1) || ch_rc=$?
                if [ "$ch_rc" -ne 0 ]; then
                    write_error "claude hooks" "chmod +x $hook_name failed" "$(error_reason "$ch_out" "$ch_rc")"
                fi
                HOOKS_CHANGED=true
                ;;
            skipped|verified|failed)
                # The library recorded a skipped (warning) or failed (error)
                # deploy once; the tracker writes the OK status and DETAIL only.
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
            # tty_interactive + read_menu_choice (incident #81, GitHub #29): a
            # non-terminal stdin never prompts. read_menu_choice prints the
            # prompt, lowercases the answer (so `A` adopts, as in the PS1
            # twin), logs it at detail, and re-asks on an empty or unrecognised
            # answer; only EOF takes the default, [s]kip -- the choice that
            # writes nothing (this menu has no overwrite option).
            if tty_interactive; then
                printf '\n  User-created hook detected: %s\n' "$hook_name" > /dev/tty
                printf '  [a]dopt to dotprofile  [s]kip\n' > /dev/tty
                choice=""
                read_menu_choice choice "a adopt s skip" "s" "skip" "adopt hook $hook_name" "  > "
                case "$choice" in
                    a|adopt)
                        # Net-new user hook -> dotprofile only (not a managed
                        # shared/ hook). Same helper for consistent backups. The
                        # library records each failure once under --tool; a
                        # failure it did not record (no file adopted) is
                        # recorded here.
                        _errors_before=$ERRORS
                        if ! adopt_managed_file --tool "claude hooks" "$hook_file" "$USER_REPO_PATH/claude/hooks/$hook_name"; then
                            if [ "$ERRORS" -eq "$_errors_before" ]; then
                                write_error "claude hooks" "adopt failed: $hook_name" "no file adopted"
                            fi
                        fi
                        ;;
                    s|skip)
                        log "Skipped adoption of $hook_name"
                        ;;
                    *)
                        # Unreachable: read_menu_choice returns only a VALID
                        # answer. Skip (writes nothing) and say so.
                        write_warn "claude hooks" "unexpected answer \"$choice\" at adopt hook $hook_name -- adoption skipped"
                        ;;
                esac
            else
                log "Non-interactive: skipped adoption prompt for $hook_name"
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

# node does not write settings.json itself: it writes the merged JSON to a staging
# file and validates it there; the shell then backs settings.json up (backup_file,
# config-file-safety.md "Backup before overwrite") and copies the staged file in, so
# a backup is made only when the file changes and invalid content is never
# written. node's stderr goes to a temp file: a crash then carries its reason.
# Both temp files are made here, not above: build-deploy replaces the hook
# deployment section and extracts this one.
MERGE_STAGE=""
MERGE_ERR=""
# 2>/dev/null: a mktemp failure is checked below (the staging file is required;
# node's stderr falls back to /dev/null)
if ! MERGE_STAGE=$(mktemp 2>/dev/null); then MERGE_STAGE=""; fi
if ! MERGE_ERR=$(mktemp 2>/dev/null); then MERGE_ERR=""; fi
if [ -z "$MERGE_ERR" ] || [ ! -f "$MERGE_ERR" ]; then
    log_detail "mktemp failed -- node's stderr for the settings merge is not captured"
    MERGE_ERR=/dev/null
fi
if [ -z "$MERGE_STAGE" ] || [ ! -f "$MERGE_STAGE" ]; then
    if [ "$MERGE_ERR" != "/dev/null" ]; then rm -f "$MERGE_ERR"; fi
    write_error "claude hooks" "settings.json hooks not merged" "cannot create a temp file for the merged settings"
    exit 1
fi

# node prints diagnostics on stdout as MSG:/WARN:/DETAIL:/REASON: lines (logged
# below; a REASON: line is the reason of the error that follows) and the status
# as the first unprefixed line; its exit code is captured (validation exits 1).
merge_rc=0
MERGE_RESULT=$(node -e "
$SORT_KEYS_JS
const fs = require('fs');
const path = require('path');
const settingsFile = process.argv[1];
const regsJson = process.argv[2];
const dryRun = process.argv[3] === 'true';
const force = process.argv[4] === 'true';
const stageFile = process.argv[5];
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
let corruptReason = '';
try {
    settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
} catch (e) {
    if (e.code !== 'ENOENT') {
        // Recorded once, below: an error, or a warning under --force
        corrupt = true;
        corruptReason = String(e.message).replace(/\\s+/g, ' ');
        console.log('REASON: ' + corruptReason);
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
    console.log('MSG: [DRY RUN] ' + settingsFile + ': merge');
    console.log('MSG:   Managed fields: ' + managedKeys.join(', '));
    if (lostKeys.length > 0) console.log('WARN: [DRY RUN] CLOBBER: would lose: ' + lostKeys.join(', '));
    if (corrupt) console.log('WARN: [DRY RUN] File is corrupt -- --force required');
    console.log('MSG:   Registered hooks: ' + regs.length);
    console.log('dry-run');
} else if (corrupt && !force) {
    console.log('DETAIL: ' + settingsFile + ' is corrupt. Use --force to overwrite, or fix manually.');
    console.log('error-corrupt');
} else if (lostKeys.length > 0 && !force) {
    console.log('REASON: would lose: ' + lostKeys.join(', '));
    console.log('error-clobber');
} else {
    // --force writes that lose data stay warnings (reference/logging.md 8.3)
    if (corrupt) console.log('WARN: settings.json was invalid JSON (' + corruptReason + ') -- overwritten (--force)');
    if (lostKeys.length > 0) console.log('WARN: fields dropped (--force): ' + lostKeys.join(', '));
    // Preserve key order on write (no sort); sortKeys is used only for the
    // order-independent unchanged comparison so reordering alone never rewrites.
    const newJson = JSON.stringify(settings, null, 2) + '\n';
    let existingJson = '';
    try { existingJson = fs.readFileSync(settingsFile, 'utf8'); } catch(e) { /* file may not exist */ }
    // A corrupt file (rewritten under --force) is never equal to the merge and is
    // not parsed again (it would throw).
    const existingNorm = (existingJson && !corrupt) ? JSON.stringify(sortKeys(JSON.parse(existingJson))) : '';
    const mergedNorm = JSON.stringify(sortKeys(settings));
    if (mergedNorm === existingNorm) {
        console.log('unchanged');
    } else {
        // Written to the staging file and validated there; the shell backs
        // settings.json up and copies it in.
        fs.writeFileSync(stageFile, newJson);

        const _v = JSON.parse(fs.readFileSync(stageFile, 'utf8'));
        const _required = ['hooks'];
        const _missing = _required.filter(k => !(k in _v));
        if (_missing.length) { console.log('REASON: validation failed: missing ' + _missing.join(', ')); process.exit(1); }

        // Validate: every manifest hook registered exactly once (generated check).
        for (const r of regs) {
            const c = (_v.hooks[r.event] || []).filter(rule => rule.hooks && rule.hooks.some(h => h.command && h.command.includes(r.hookId))).length;
            if (c !== 1) { console.log('REASON: validation failed: expected 1 ' + r.event + ' ' + r.hookId + ' hook, got ' + c); process.exit(1); }
        }

        // Validate hook schema: command-type must have command field,
        // prompt-type must have prompt field (not command). (v0.60 incident guard.)
        for (const [event, rules] of Object.entries(_v.hooks || {})) {
            for (const rule of (rules || [])) {
                for (const h of (rule.hooks || [])) {
                    if (h.type === 'command' && !h.command) {
                        console.log('REASON: validation failed: ' + event + ' hook has type \"command\" but no command field');
                        process.exit(1);
                    }
                    if (h.type === 'prompt') {
                        if (!h.prompt) {
                            console.log('REASON: validation failed: ' + event + ' hook has type \"prompt\" but no prompt field.');
                            process.exit(1);
                        }
                        if (h.command) {
                            console.log('REASON: validation failed: ' + event + ' hook has type \"prompt\" with a command field.');
                            process.exit(1);
                        }
                    }
                }
            }
        }

        console.log('write');
    }
}
" "$SETTINGS_FILE" "$REGS_JSON" "$DRY_RUN" "$FORCE" "$MERGE_STAGE" 2>"$MERGE_ERR") || merge_rc=$?

# Log node's prefixed diagnostics; the first unprefixed line is the status. The
# first REASON: line is the reason of the error recorded below.
MERGE_STATUS=""
MERGE_REASON=""
while IFS= read -r line; do
    case "$line" in
        "MSG: "*)    log "${line#MSG: }" ;;
        "WARN: "*)   write_warn "claude hooks" "${line#WARN: }" ;;
        "DETAIL: "*) log_detail "settings-merge: ${line#DETAIL: }" ;;
        "REASON: "*) if [ -z "$MERGE_REASON" ]; then MERGE_REASON="${line#REASON: }"; fi ;;
        "CHANGED: "*) ;;
        *) if [ -z "$MERGE_STATUS" ]; then MERGE_STATUS="$line"; fi ;;
    esac
done <<< "$MERGE_RESULT"
MERGE_ERR_TEXT=""
if [ "$MERGE_ERR" != "/dev/null" ]; then
    MERGE_ERR_TEXT=$(<"$MERGE_ERR")
    rm -f "$MERGE_ERR"
fi
# A non-zero node exit (validation, uncaught error) overrides the status.
if [ "$merge_rc" -ne 0 ]; then MERGE_STATUS="error-exit"; fi

case "$MERGE_STATUS" in
    write)
        # Back up only now that the file changes; then copy the validated
        # content in and check that the file holds it.
        backup_file "$SETTINGS_FILE"
        cp_rc=0
        cp_out=$(cp "$MERGE_STAGE" "$SETTINGS_FILE" 2>&1) || cp_rc=$?
        if [ "$cp_rc" -ne 0 ]; then
            write_error "claude hooks" "could not write $(display_path "$SETTINGS_FILE")" "$(error_reason "$cp_out" "$cp_rc")"
        elif ! cmp -s "$MERGE_STAGE" "$SETTINGS_FILE"; then
            write_error "claude hooks" "could not write $(display_path "$SETTINGS_FILE")" "the written file differs from the merged settings"
        else
            log_ok "Hooks deployed to $(display_path "$SETTINGS_FILE")"
            HOOKS_CHANGED=true
        fi
        ;;
    unchanged)
        log_ok "Settings unchanged: $(display_path "$SETTINGS_FILE")"
        ;;
    dry-run)
        log "[DRY RUN] Would merge settings"
        ;;
    error-corrupt)
        write_error "claude hooks" "settings.json is corrupt -- use --force to overwrite" "$MERGE_REASON"
        ;;
    error-clobber)
        write_error "claude hooks" "merge would lose fields -- use --force to proceed" "$MERGE_REASON"
        ;;
    error-exit)
        # A validation failure: node's REASON: line (same WHAT as the .ps1). A
        # crash: its stderr, and the exit code in WHAT.
        if [ -n "$MERGE_REASON" ]; then
            write_error "claude hooks" "settings.json hooks merge failed" "$MERGE_REASON"
        else
            write_error "claude hooks" "settings.json hooks merge failed (node exit $merge_rc)" "$(error_reason "$MERGE_ERR_TEXT" "$merge_rc")"
        fi
        ;;
    *)
        write_error "claude hooks" "settings.json hooks merge failed" "$(error_reason "$MERGE_RESULT" "$merge_rc")"
        ;;
esac
rm -f "$MERGE_STAGE"

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
