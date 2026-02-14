#!/usr/bin/env bash
# setup-cursor-mcp.sh — Installs/updates MCP servers for Cursor on macOS/Linux
# Safe to re-run — replaces ~/.cursor/mcp.json with latest config.
#
# User-level MCP: chrome-devtools only.
# For vercel/webflow, use `aitools --addmcp` at the project level.
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

# Write the config — chrome-devtools only (macOS uses npx directly, no cmd /c wrapper)
cat > "$mcp_json" << 'EOF'
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    }
  }
}
EOF

log_ok "Cursor MCP config written to $(display_path "$mcp_json")"
log "Server configured: chrome-devtools (stdio via npx)"
log "For project-level servers (vercel, webflow): aitools --addmcp <name>"
log ""
log "Next steps:"
log "  1. Restart Cursor"
log "  2. Go to Cursor Settings > Tools & MCP to see the servers"
