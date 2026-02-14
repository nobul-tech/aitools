#!/usr/bin/env bash
# setup-user-mcp.sh — Installs/updates user-level MCP servers for Claude Code on macOS/Linux
# Safe to re-run — removes and re-adds each server to ensure latest config.
#
# User-level MCP: chrome-devtools only.
# For vercel/webflow, use `aitools --addmcp` at the project level.

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

# Check that claude CLI is available
if ! command -v claude &> /dev/null; then
    log_error "'claude' CLI not found in PATH. Install Claude Code first: https://claude.ai/download"
    exit 1
fi

# Check that Node.js is available (required for Chrome DevTools MCP)
if ! command -v node &> /dev/null; then
    log_error "Node.js not found. Install via 'aitools install' or manually: https://nodejs.org"
    exit 1
else
    log_ok "Node.js $(node --version) found"
fi

# --- Legacy cleanup: remove vercel/webflow from user scope ---
for server in vercel webflow; do
    if claude mcp remove "$server" --scope user 2>/dev/null; then
        log_ok "Removed legacy $server from user scope (now project-level via --addmcp)"
    fi
done

# --- Chrome DevTools (stdio, user scope) ---
add_stdio_server() {
    local name="$1"
    shift

    # Remove existing (ignore errors if not found)
    if claude mcp remove "$name" --scope user 2>/dev/null; then
        log "Removed existing $name config"
    fi

    log "Adding $name..."
    claude mcp add "$name" --scope user -- "$@"
    log_ok "$name configured"
}

log "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools — local stdio server via npx (no cmd /c needed on macOS)
add_stdio_server "chrome-devtools" npx -y chrome-devtools-mcp@latest

log_ok "User-level MCP configured (chrome-devtools only)"
log "For project-level servers (vercel, webflow): aitools --addmcp <name>"
