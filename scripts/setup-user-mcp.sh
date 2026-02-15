#!/usr/bin/env bash
# setup-user-mcp.sh — Installs/updates user-level MCP servers for Claude Code on macOS/Linux
# Safe to re-run — removes and re-adds each server to ensure latest config.
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled by default (deny rules).
# Use `aitools --addmcp` to enable per project.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/ai-tooling"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ai-tooling"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-user-mcp"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; }

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# Check that claude CLI is available
if ! command -v claude &> /dev/null; then
    log_error "'claude' CLI not found in PATH. Install Claude Code first: https://claude.ai/download"
    exit 1
fi

# Check that Node.js is available (required for Chrome DevTools MCP and settings merge)
if ! command -v node &> /dev/null; then
    log_error "Node.js not found. Install via 'aitools install' or manually: https://nodejs.org"
    exit 1
else
    log_ok "Node.js $(node --version) found"
fi

# --- Add all three MCP servers at user scope ---

add_mcp_server() {
    local name="$1"
    shift

    # Unset CLAUDECODE to allow running inside a Claude Code session
    local saved_claudecode="${CLAUDECODE:-}"
    unset CLAUDECODE

    # Remove existing (ignore errors if not found)
    if claude mcp remove "$name" --scope user 2>/dev/null; then
        log "Removed existing $name config"
    fi

    log "Adding $name..."
    if claude mcp add "$@"; then
        log_ok "$name configured"
    else
        log_error "Failed to add $name"
    fi

    # Restore CLAUDECODE
    if [ -n "$saved_claudecode" ]; then
        export CLAUDECODE="$saved_claudecode"
    fi
}

log "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools — local stdio server via npx
add_mcp_server "chrome-devtools" chrome-devtools --scope user npx chrome-devtools-mcp@latest

# Vercel — remote HTTP server (disabled by default via deny rules below)
add_mcp_server "vercel" --transport http --scope user vercel https://mcp.vercel.com

# Webflow — remote HTTP server (disabled by default via deny rules below)
add_mcp_server "webflow" --transport http --scope user webflow https://mcp.webflow.com/mcp

# --- Merge deny rules into ~/.claude/settings.json ---
# Vercel and Webflow are disabled by default at user level.
# Projects enable them via .claude/settings.local.json (aitools --addmcp).

settings_file="$HOME/.claude/settings.json"
log "Merging deny rules into $(display_path "$settings_file")..."

node -e "
const fs = require('fs');
const path = require('path');
const f = process.argv[1];
const dir = path.dirname(f);

// Ensure directory exists
if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

// Read existing settings
let settings = {};
try { settings = JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}

// Ensure permissions.deny exists
if (!settings.permissions) settings.permissions = {};
if (!Array.isArray(settings.permissions.deny)) settings.permissions.deny = [];

// Add deny rules if not already present
const denyRules = ['MCP(vercel)', 'MCP(webflow)'];
for (const rule of denyRules) {
    if (!settings.permissions.deny.includes(rule)) {
        settings.permissions.deny.push(rule);
    }
}

fs.writeFileSync(f, JSON.stringify(settings, null, 2) + '\n');
" "$settings_file"

log_ok "Deny rules set for vercel, webflow in $(display_path "$settings_file")"

log_ok "User-level MCP configured (all servers; vercel/webflow disabled by default)"
log "To enable per project: aitools --addmcp vercel"
log "To check status: aitools mcp"
