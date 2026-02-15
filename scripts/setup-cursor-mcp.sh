#!/usr/bin/env bash
# setup-cursor-mcp.sh — Installs/updates MCP servers for Cursor on macOS/Linux
# Safe to re-run — replaces ~/.cursor/mcp.json with latest config.
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled via `agent mcp disable`.
# Use `aitools --addmcp` to enable per project.
#
# Cursor uses its own MCP config at ~/.cursor/mcp.json (separate from Claude Code's ~/.claude.json).
# Remote servers use the "url" key directly. Local stdio servers use "command" + "args".

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/ai-tooling"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ai-tooling"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-cursor-mcp"
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

# Check that Node.js is available (required for Chrome DevTools MCP)
if ! command -v node &> /dev/null; then
    log_error "Node.js not found. Install via 'aitools install' or manually: https://nodejs.org"
    exit 1
else
    log_ok "Node.js $(node --version) found"
fi

# Ensure ~/.cursor directory exists
cursor_dir="$HOME/.cursor"
mkdir -p "$cursor_dir"

mcp_json="$cursor_dir/mcp.json"

if [ -f "$mcp_json" ]; then
    log "Replacing existing $(display_path "$mcp_json")"
else
    log "Creating $(display_path "$mcp_json")"
fi

# Write the config — all three servers (macOS uses npx directly, no cmd /c wrapper)
cat > "$mcp_json" << 'EOF'
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    },
    "vercel": {
      "url": "https://mcp.vercel.com"
    },
    "webflow": {
      "url": "https://mcp.webflow.com/mcp"
    }
  }
}
EOF

log_ok "Cursor MCP config written to $(display_path "$mcp_json")"
log "Servers configured: chrome-devtools (stdio), vercel (http), webflow (http)"

# --- Disable vercel/webflow via Cursor CLI if available ---
if command -v agent &>/dev/null; then
    for server in vercel webflow; do
        if agent mcp disable "$server" 2>&1; then
            log_ok "$server disabled in Cursor"
        else
            log_error "Failed to disable $server in Cursor"
        fi
    done
else
    log "Cursor CLI (agent) not found — disable vercel/webflow manually:"
    log "  Cursor Settings > Features > MCP > toggle off vercel and webflow"
    log "  Or install Cursor CLI: aitools install"
fi

log ""
log "Next steps:"
log "  1. Restart Cursor"
log "  2. Go to Cursor Settings > Tools & MCP to verify servers"
log "  3. To enable vercel/webflow per project: aitools --addmcp vercel"
