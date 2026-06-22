#!/usr/bin/env bash
# setup-user-settings.sh — Syncs ~/.claude/settings.json with profile.json (source of truth)
# Safe to re-run. Platform: macOS/Linux (Windows: setup-user-settings.ps1).
# Reference: reference/user-repo.md, .claude/rules/managed-file-deployment.md.
#
# profile.json `claude.settings` is the source of truth for ~/.claude/settings.json,
# EXCEPT `hooks` (manifest-owned, deployed by setup-user-hooks). For each managed leaf
# (arbitrary keys; permissions per-rule across allow/ask/deny): live-only -> auto-adopt
# into profile; equal -> no-op; differ/live-missing -> granular per-leaf prompt
# (overwrite/adopt/skip/abort). Obsolete deny rules are purged before the scan.
#
# Managed: all of ~/.claude/settings.json except `hooks`.
# Source of truth: profile.json (dotprofile repo, via config.json userRepoPath).

# --- BEGIN settings body (extracted by build-deploy) ---
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
logging_init "setup-user-settings"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

# --- Require node for JSON manipulation ---
if ! command -v node &>/dev/null; then
    log_error "node required for settings sync"
    exit 1
fi

SETTINGS_FILE="$HOME/.claude/settings.json"
# Obsolete deny rules purged before the adopt-scan (CC no longer reliably honors
# permissions.deny for built-in subagents; vercel/webflow gating retired).
DEPRECATED_RULES="MCP(vercel),MCP(webflow),Agent(claude-code-guide)"

# --- Resolve profile.json (source of truth) via config.json userRepoPath ---
# `|| true`: key is absent until 'aitools user init' runs; without the guard set -e aborts.
USER_REPO_PATH=$(read_config_key "$HOME/.aitools/config.json" "userRepoPath") || true
PROFILE_FILE=""
[ -n "$USER_REPO_PATH" ] && PROFILE_FILE="$USER_REPO_PATH/profile.json"

if [ -z "$USER_REPO_PATH" ] || [ ! -d "$USER_REPO_PATH" ]; then
    log_warn "No user repo configured (run 'aitools user init') -- skipping settings sync"
    write_summary WARN "claude settings" "no profile (run aitools user init)"
elif [ ! -f "$PROFILE_FILE" ]; then
    log_warn "profile.json not found at $(display_path "$PROFILE_FILE") -- skipping settings sync"
    write_summary WARN "claude settings" "profile.json missing"
elif [ ! -f "$SETTINGS_FILE" ]; then
    log "No settings.json yet at $(display_path "$SETTINGS_FILE") -- nothing to sync"
    write_summary OK "claude settings" "no settings.json"
else
    # --- Legacy migration: claude.{autoMemory,alwaysThinking,effortLevel} ---
    #     -> claude.settings.{autoMemoryEnabled,alwaysThinkingEnabled,effortLevel}
    # Renames the old flat prefs into the settings mirror (only if the mirror lacks
    # them), then removes the legacy keys. Idempotent; safe once migrated.
    if [ "$DRY_RUN" != "true" ] && node -e 'const c=(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).claude)||{}; process.exit(["autoMemory","alwaysThinking","effortLevel"].some(k=>Object.prototype.hasOwnProperty.call(c,k))?0:1)' "$PROFILE_FILE" 2>/dev/null; then
        backup_file "$PROFILE_FILE"
        MIGRATED=$(node -e '
const fs = require("fs");
const p = process.argv[1];
const o = JSON.parse(fs.readFileSync(p, "utf8"));
const c = o.claude = o.claude || {};
const s = c.settings = (c.settings && typeof c.settings === "object") ? c.settings : {};
const map = { autoMemory: "autoMemoryEnabled", alwaysThinking: "alwaysThinkingEnabled", effortLevel: "effortLevel" };
const migrated = [];
for (const [legacy, target] of Object.entries(map)) {
    if (Object.prototype.hasOwnProperty.call(c, legacy)) {
        if (!Object.prototype.hasOwnProperty.call(s, target)) { s[target] = c[legacy]; migrated.push(legacy + "->" + target); }
        delete c[legacy];
    }
}
if (migrated.length) fs.writeFileSync(p, JSON.stringify(o, null, 2) + "\n");
process.stdout.write(migrated.join(", "));
' "$PROFILE_FILE") || log_warn "legacy preference migration failed (non-fatal)"
        [ -n "$MIGRATED" ] && log_ok "Migrated legacy prefs into claude.settings: $MIGRATED"
    fi

    # --- Sync settings.json <-> profile.json (granular per-leaf review) ---
    if [ "$DRY_RUN" = "true" ]; then
        sync_managed_json "$SETTINGS_FILE" "$PROFILE_FILE" "claude.settings" "hooks" "$DEPRECATED_RULES"
        write_summary OK "claude settings" "dry-run"
    else
        sync_managed_json "$SETTINGS_FILE" "$PROFILE_FILE" "claude.settings" "hooks" "$DEPRECATED_RULES"
        case "$SYNC_MANAGED_JSON_RESULT" in
            updated|created) write_summary OK "claude settings" "synced" ;;
            *)               write_summary OK "claude settings" "verified" ;;
        esac
    fi
fi
# --- END settings body (extracted by build-deploy) ---

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
