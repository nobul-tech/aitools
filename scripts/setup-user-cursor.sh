#!/usr/bin/env bash
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Safe to re-run — checks each step and skips what's already done.
# Install commands reference: reference/tool-install-sources.md
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)

set -euo pipefail

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

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

CURSOR_DIR="$HOME/.cursor"
CLI_CONFIG="$CURSOR_DIR/cli-config.json"

# Track status for summary (plain vars -- bash 3.2 compat, no associative arrays)
STATUS_ripgrep=""
STATUS_cursorCli=""
STATUS_cliConfig=""

# --- 1. ripgrep (rg) ---

log "Step 1: ripgrep (rg)"

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

# --- 2. Cursor CLI (agent) ---

log "Step 2: Cursor CLI (agent)"

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

# --- 3. cli-config.json (merge, not overwrite) ---

log "Step 3: cli-config.json"

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

// --- Read profile preferences ---
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

// --- Read existing cli-config.json ---
let config = {};
try { config = JSON.parse(fs.readFileSync(f, 'utf8')); } catch (e) { if (e.code !== 'ENOENT') console.error('Warning: ' + f + ' is invalid JSON, starting with empty config'); }
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

    // Post-write validation
    const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
    const _missing = ['version'].filter(k => !(k in _v));
    if (_missing.length) { console.error('Validation failed: missing ' + _missing.join(', ')); process.exit(1); }

    console.log(before === '{}' ? 'created' : 'merged');
}
" "$CLI_CONFIG")

    case "$MERGE_RESULT" in
        unchanged)
            log_ok "Already up to date: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="already up to date" ;;
        created)
            log_ok "Created: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="created" ;;
        merged)
            log_ok "Merged preferences into: $(display_path "$CLI_CONFIG")"
            STATUS_cliConfig="merged" ;;
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

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
