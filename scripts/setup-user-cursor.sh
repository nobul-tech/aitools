#!/usr/bin/env bash
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Safe to re-run — checks each step and skips what's already done.
#
# Does four things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Writes ~/.cursor/cli-config.json (skips if already up to date)
#   4. Copies User Rules to clipboard for pasting into Cursor Settings > Rules

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/ai-tooling"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ai-tooling"
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_RULES_PATH="${1:-$SCRIPT_DIR/../shared/cursor-rules/user-rules.md}"

CURSOR_DIR="$HOME/.cursor"
CLI_CONFIG="$CURSOR_DIR/cli-config.json"

# Track status for summary (plain vars -- bash 3.2 compat, no associative arrays)
STATUS_ripgrep=""
STATUS_cursorCli=""
STATUS_cliConfig=""
STATUS_userRules=""

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

# --- 3. cli-config.json ---

log "Step 3: cli-config.json"

EXPECTED_CONFIG='{
  "version": 1,
  "editor": {
    "vimMode": false
  },
  "permissions": {
    "allow": [],
    "deny": []
  }
}'

mkdir -p "$CURSOR_DIR"

if [ -f "$CLI_CONFIG" ]; then
    EXISTING_CONFIG=$(cat "$CLI_CONFIG")
    if [ "$EXISTING_CONFIG" = "$EXPECTED_CONFIG" ]; then
        log_ok "Already up to date: $(display_path "$CLI_CONFIG")"
        STATUS_cliConfig="already up to date"
    else
        printf '%s' "$EXPECTED_CONFIG" > "$CLI_CONFIG"
        log_ok "Updated: $(display_path "$CLI_CONFIG")"
        STATUS_cliConfig="updated"
    fi
else
    printf '%s' "$EXPECTED_CONFIG" > "$CLI_CONFIG"
    log_ok "Created: $(display_path "$CLI_CONFIG")"
    STATUS_cliConfig="created"
fi

# --- 4. Copy User Rules to clipboard ---

log "Step 4: User Rules"

if [ -f "$USER_RULES_PATH" ]; then
    if [ -t 1 ]; then
        # Interactive: copy to clipboard
        copied=false
        if command -v pbcopy &>/dev/null; then
            pbcopy < "$USER_RULES_PATH"
            copied=true
        elif command -v xclip &>/dev/null; then
            xclip -selection clipboard < "$USER_RULES_PATH"
            copied=true
        fi

        if $copied; then
            log_ok "Copied to clipboard from: $(display_path "$USER_RULES_PATH")"
            log "Paste into: Cursor Settings > Rules"
            STATUS_userRules="copied to clipboard -- paste into Cursor Settings > Rules"
        else
            log_warn "No clipboard command found (pbcopy/xclip). Copy manually from: $(display_path "$USER_RULES_PATH")"
            STATUS_userRules="NOT copied (no clipboard tool) -- copy manually"
        fi
    else
        # Non-interactive (called from deploy_configs): skip clipboard
        log_ok "User Rules source: $(display_path "$USER_RULES_PATH")"
        STATUS_userRules="available (run interactively to copy to clipboard)"
    fi
else
    log_warn "User Rules file not found at $(display_path "$USER_RULES_PATH"). Skipping clipboard copy."
    STATUS_userRules="SKIPPED (file not found)"
fi

# --- Summary ---

log "=============================="
log "Summary:"
log "  ripgrep:       ${STATUS_ripgrep}"
log "  Cursor CLI:    ${STATUS_cursorCli}"
log "  cli-config:    ${STATUS_cliConfig}"
log "  User Rules:    ${STATUS_userRules}"
log "=============================="

# Open User Rules file so user can see what to paste (interactive only)
if [ -t 1 ] && [ -f "$USER_RULES_PATH" ]; then
    if [[ "$OSTYPE" == darwin* ]]; then
        open "$USER_RULES_PATH"
    else
        xdg-open "$USER_RULES_PATH" 2>/dev/null || true
    fi
fi
