#!/usr/bin/env bash
# setup-cursor-mcp.sh — Installs/updates MCP servers for Cursor on macOS/Linux
# Safe to re-run — merges managed servers into ~/.cursor/mcp.json.
#
# Managed fields: mcpServers.chrome-devtools, mcpServers.vercel, mcpServers.webflow
# Preserved: all other mcpServers entries, all other top-level keys
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled via `agent mcp disable`.
# Use `aitools --addmcp` to enable per project.
#
# Cursor uses its own MCP config at ~/.cursor/mcp.json (separate from Claude Code's ~/.claude.json).
# Remote servers use the "url" key directly. Local stdio servers use "command" + "args".

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-cursor-mcp"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }

# Backup a file before overwriting. Keeps at most $max_backups copies.
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

backup_file "$mcp_json"
if [ -f "$mcp_json" ]; then
    log "Merging managed servers into $(display_path "$mcp_json")"
else
    log "Creating $(display_path "$mcp_json")"
fi

# Merge managed servers — preserves user-added servers and other keys
node -e "
const fs = require('fs');
const f = process.argv[1];

// Read existing config (ENOENT = start fresh, parse error = warn)
let config = {};
try {
    config = JSON.parse(fs.readFileSync(f, 'utf8'));
} catch (e) {
    if (e.code !== 'ENOENT') {
        console.error('Warning: ' + f + ' is invalid JSON, starting with empty config');
    }
}

// Ensure mcpServers exists
if (!config.mcpServers || typeof config.mcpServers !== 'object') {
    config.mcpServers = {};
}

// Set managed servers (macOS uses npx directly, no cmd /c wrapper)
config.mcpServers['chrome-devtools'] = {
    command: 'npx',
    args: ['-y', 'chrome-devtools-mcp@latest', '--isolated']
};
config.mcpServers['vercel'] = { url: 'https://mcp.vercel.com' };
config.mcpServers['webflow'] = { url: 'https://mcp.webflow.com/mcp' };

fs.writeFileSync(f, JSON.stringify(config, null, 2) + '\n');
" "$mcp_json"

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

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
