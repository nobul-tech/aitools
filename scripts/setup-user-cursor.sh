#!/usr/bin/env bash
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Safe to re-run — checks each step and skips what's already done.
# Install commands reference: reference/tool-registry.md
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)
#
# Managed fields: version, editor, permissions, model, hasChangedDefaultModel
# Preserved: authInfo, privacyCache, network, statsigBootstrap, maxMode, all other fields

# --- BEGIN cursor body (extracted by build-deploy) ---
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
SCRIPT_NAME="setup-user-cursor"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }
write_summary() {
    [ -n "${AITOOLS_SUMMARY_FILE:-}" ] && printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
}

backup_file() {
    local file="$1" max_backups=20
    [ -f "$file" ] || return 0
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    cp "$file" "${file}.bak.${ts}"
    # Prune oldest beyond limit
    ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1)) | xargs rm -f 2>/dev/null
    log "Backed up $(display_path "$file")"
}

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

CURSOR_DIR="$HOME/.cursor"
CLI_CONFIG="$CURSOR_DIR/cli-config.json"

# Track status for summary (plain vars -- bash 3.2 compat, no associative arrays)
STATUS_ripgrep=""
STATUS_cursorCli=""
STATUS_cliConfig=""

# --- 1. ripgrep (rg) ---

log "Step 1: ripgrep (rg)"

if [ "$DRY_RUN" = "true" ]; then
    if command -v rg &>/dev/null; then
        RG_VERSION=$(rg --version | head -1)
        log "[DRY RUN] ripgrep already installed: $RG_VERSION"
        STATUS_ripgrep="already installed ($RG_VERSION)"
    else
        log "[DRY RUN] Would install ripgrep via brew"
        STATUS_ripgrep="would install"
    fi
else
    if command -v rg &>/dev/null; then
        RG_VERSION=$(rg --version | head -1)
        log_ok "Already installed: $RG_VERSION"
        STATUS_ripgrep="already installed ($RG_VERSION)"
    else
        if command -v brew &>/dev/null; then
            log "Installing ripgrep via brew..."
            brew install ripgrep

            if command -v rg &>/dev/null; then
                RG_VERSION=$(rg --version | head -1)
                log_ok "Installed: $RG_VERSION"
                STATUS_ripgrep="installed ($RG_VERSION)"
            else
                log_warn "brew install completed but 'rg' not found in PATH. Restart terminal to verify."
                STATUS_ripgrep="installed (restart terminal to verify)"
            fi
        else
            log_warn "Homebrew not found. Install ripgrep manually: brew install ripgrep"
            STATUS_ripgrep="SKIPPED (brew not found)"
        fi
    fi
fi

# --- 2. Cursor CLI (agent) ---

log "Step 2: Cursor CLI (agent)"

if [ "$DRY_RUN" = "true" ]; then
    if command -v agent &>/dev/null; then
        AGENT_VERSION=$(agent --version)
        log "[DRY RUN] Cursor CLI already installed: $AGENT_VERSION"
        STATUS_cursorCli="already installed ($AGENT_VERSION)"
    else
        log "[DRY RUN] Would install Cursor CLI"
        STATUS_cursorCli="would install"
    fi
else
    if command -v agent &>/dev/null; then
        AGENT_VERSION=$(agent --version)
        log_ok "Already installed: $AGENT_VERSION"
        STATUS_cursorCli="already installed ($AGENT_VERSION)"
    else
        log "Installing Cursor CLI..."
        curl https://cursor.com/install -fsS | bash

        if command -v agent &>/dev/null; then
            AGENT_VERSION=$(agent --version)
            log_ok "Installed: $AGENT_VERSION"
            STATUS_cursorCli="installed ($AGENT_VERSION)"
        else
            log_warn "Cursor CLI install completed but 'agent' not found in PATH. Restart terminal to verify."
            STATUS_cursorCli="installed (restart terminal to verify)"
        fi
    fi
fi

# --- 3. cli-config.json (merge, not overwrite) ---

log "Step 3: cli-config.json"

if [ "$DRY_RUN" != "true" ]; then
    backup_file "$CLI_CONFIG"
fi

mkdir -p "$CURSOR_DIR"

if ! command -v node &>/dev/null; then
    log_warn "node not found -- skipping cli-config.json merge"
    STATUS_cliConfig="SKIPPED (node not found)"
else
    # Read cursor.cli preferences from profile.json (via config.json -> userRepoPath).
    # Falls back to defaults if profile not found.

    MERGE_RESULT=$(node -e "
const fs = require('fs');
const path = require('path');
const f = process.argv[1];
const dryRun = process.argv[2] === 'true';
const force = process.argv[3] === 'true';

// --- BEGIN profile preferences (replaced by build-deploy) ---
let vimMode = false;
let modelId = 'auto';
try {
    const cfgPath = path.join(process.env.HOME || process.env.USERPROFILE, '.aitools', 'config.json');
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    if (cfg.userRepoPath) {
        const pf = JSON.parse(fs.readFileSync(path.join(cfg.userRepoPath, 'profile.json'), 'utf8'));
        if (pf.cursor && pf.cursor.cli) {
            if (typeof pf.cursor.cli.vimMode === 'boolean') vimMode = pf.cursor.cli.vimMode;
            if (typeof pf.cursor.cli.model === 'string') modelId = pf.cursor.cli.model;
        }
    }
} catch (e) { if (e.code !== 'ENOENT') console.error('Warning: could not read profile preferences: ' + e.message); }
// --- END profile preferences (replaced by build-deploy) ---

// --- Read existing cli-config.json ---
let config = {};
let corrupt = false;
try {
    config = JSON.parse(fs.readFileSync(f, 'utf8'));
} catch (e) {
    if (e.code !== 'ENOENT') {
        corrupt = true;
        console.error('Warning: ' + f + ' is invalid JSON');
    }
}
const beforeKeys = Object.keys(config);
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

// --- Clobber detection ---
const managedKeys = ['version', 'editor', 'permissions', 'model', 'hasChangedDefaultModel'];
const afterKeys = Object.keys(config);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

const after = JSON.stringify(config);

if (dryRun) {
    console.error('[DRY RUN] ' + f + ': merge');
    console.error('  Managed fields: ' + managedKeys.join(', '));
    if (lostKeys.length > 0) console.error('  CLOBBER WARNING: would lose: ' + lostKeys.join(', '));
    if (corrupt) console.error('  File is corrupt -- --force required');
    console.log(before === after && !corrupt ? 'unchanged' : 'would-merge');
} else if (corrupt && !force) {
    console.error('ERROR: ' + f + ' is corrupt. Use --force to overwrite, or fix manually.');
    console.log('error-corrupt');
} else if (lostKeys.length > 0 && !force) {
    console.error('ERROR: merge would lose fields: ' + lostKeys.join(', ') + '. Use --force to proceed.');
    console.log('error-clobber');
} else {
    if (before === after) {
        console.log('unchanged');
    } else {
        if (corrupt) console.error('Warning: proceeding with --force on corrupt file');
        if (lostKeys.length > 0) console.error('Warning: proceeding with --force, losing fields: ' + lostKeys.join(', '));
        fs.writeFileSync(f, JSON.stringify(config, null, 2) + '\n');

        // Post-write validation
        const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
        const _missing = ['version'].filter(k => !(k in _v));
        if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }

        console.log(before === '{}' ? 'created' : 'merged');
    }
}
" "$CLI_CONFIG" "$DRY_RUN" "$FORCE")

    case "$MERGE_RESULT" in
        unchanged)
            log_ok "Already up to date: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="already up to date"
            write_summary OK "cursor rules" "merged" ;;
        created)
            log_ok "Created: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="created"
            write_summary OK "cursor rules" "merged" ;;
        merged)
            log_ok "Merged preferences into: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="merged"
            write_summary OK "cursor rules" "merged" ;;
        would-merge)
            log "[DRY RUN] Would write merged config"
            STATUS_cliConfig="would merge (dry-run)" ;;
        error-corrupt)
            log_error "$(display_path "$CLI_CONFIG") is corrupt. Use --force to overwrite."
            STATUS_cliConfig="ERROR (corrupt, needs --force)" ;;
        error-clobber)
            log_error "$(display_path "$CLI_CONFIG") merge would lose fields. Use --force to proceed."
            STATUS_cliConfig="ERROR (clobber, needs --force)" ;;
        *)
            log_error "Unexpected merge result: $MERGE_RESULT"
            STATUS_cliConfig="ERROR" ;;
    esac
fi

# --- Summary ---

log "=============================="
log "Summary:"
log "  ripgrep:       ${STATUS_ripgrep}"
log "  Cursor CLI:    ${STATUS_cursorCli}"
log "  cli-config:    ${STATUS_cliConfig}"
log "=============================="
# --- END cursor body (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
# --- END exit (extracted by build-deploy) ---
