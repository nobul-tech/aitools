#!/usr/bin/env bash
# setup-cursor-ide-mcp.sh — Installs/updates MCP servers for Cursor IDE on macOS/Linux
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
logging_init "setup-cursor-ide-mcp"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

log "Setting up MCP servers for Cursor IDE (user scope)..."

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

if [ "$DRY_RUN" != "true" ]; then
    backup_file "$mcp_json"
fi
if [ -f "$mcp_json" ]; then
    log "Merging managed servers into $(display_path "$mcp_json")"
else
    log "Creating $(display_path "$mcp_json")"
fi

# Merge managed servers — preserves user-added servers and other keys
MERGE_RESULT=$(node -e "
const fs = require('fs');
const f = process.argv[1];
const dryRun = process.argv[2] === 'true';
const force = process.argv[3] === 'true';

// Read existing config (ENOENT = start fresh, parse error = warn)
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
const beforeJson = JSON.stringify(config);
const beforeKeys = Object.keys(config);

// Ensure mcpServers exists
if (!config.mcpServers || typeof config.mcpServers !== 'object') {
    config.mcpServers = {};
}

// Snapshot managed server entries before merge
const managedServers = ['chrome-devtools', 'vercel', 'webflow'];
const serversBefore = {};
for (const s of managedServers) serversBefore[s] = JSON.stringify(config.mcpServers[s]);

// Set managed servers (macOS uses npx directly, no cmd /c wrapper)
config.mcpServers['chrome-devtools'] = {
    command: 'npx',
    args: ['-y', 'chrome-devtools-mcp@latest', '--isolated']
};
config.mcpServers['vercel'] = { url: 'https://mcp.vercel.com' };
config.mcpServers['webflow'] = { url: 'https://mcp.webflow.com/mcp' };

// Clobber detection
const managedKeys = ['mcpServers'];
const afterKeys = Object.keys(config);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

if (dryRun) {
    console.error('[DRY RUN] ' + f + ': merge MCP servers');
    console.error('  Managed fields: mcpServers.chrome-devtools, mcpServers.vercel, mcpServers.webflow');
    if (lostKeys.length > 0) console.error('  CLOBBER WARNING: would lose: ' + lostKeys.join(', '));
    if (corrupt) console.error('  File is corrupt -- --force required');
    console.log('dry-run');
} else if (corrupt && !force) {
    console.error('ERROR: ' + f + ' is corrupt. Use --force to overwrite, or fix manually.');
    console.log('error-corrupt');
} else if (lostKeys.length > 0 && !force) {
    console.error('ERROR: merge would lose fields: ' + lostKeys.join(', ') + '. Use --force to proceed.');
    console.log('error-clobber');
} else {
    if (corrupt) console.error('Warning: proceeding with --force on corrupt file');
    if (lostKeys.length > 0) console.error('Warning: proceeding with --force, losing fields: ' + lostKeys.join(', '));
    const afterJson = JSON.stringify(config, null, 2) + '\n';
    if (!corrupt && lostKeys.length === 0 && beforeJson === JSON.stringify(JSON.parse(afterJson))) {
        console.log('unchanged');
    } else {
        fs.writeFileSync(f, afterJson);
        // Post-write validation
        const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
        if (!_v.mcpServers) { console.error('Validation failed: missing mcpServers'); process.exit(1); }
        // Detect per-server changes
        const changed = [];
        for (const s of managedServers) {
            const oldVal = serversBefore[s];
            const newVal = JSON.stringify(config.mcpServers[s]);
            if (oldVal !== newVal) changed.push(s + ': ' + (oldVal || '(unset)') + ' -> ' + newVal);
        }
        console.log('ok');
        changed.forEach(c => console.log('CHANGED: ' + c));
    }
}
" "$mcp_json" "$DRY_RUN" "$FORCE")

MCP_CHANGED=false
case "$MERGE_RESULT" in
    ok)
        MCP_CHANGED=true
        log_ok "Cursor MCP config written to $(display_path "$mcp_json")"
        log "Servers configured: chrome-devtools (stdio), vercel (http), webflow (http)"
        emit_merge_details "$MERGE_RESULT" "cursor ide mcp"
        write_summary OK "cursor ide mcp" "updated" ;;
    unchanged)
        log_ok "Cursor MCP config already up to date"
        write_summary OK "cursor ide mcp" "unchanged" ;;
    dry-run)
        log "[DRY RUN] Would write Cursor MCP config"
        log "  Servers: chrome-devtools (stdio), vercel (http), webflow (http)" ;;
    error-corrupt)
        log_error "$(display_path "$mcp_json") is corrupt. Use --force to overwrite."
        write_summary ERROR "cursor ide mcp" "config corrupt" ;;
    error-clobber)
        log_error "$(display_path "$mcp_json") merge would lose fields. Use --force to proceed."
        write_summary ERROR "cursor ide mcp" "merge would lose fields" ;;
    *)
        log_error "Unexpected merge result: $MERGE_RESULT"
        write_summary ERROR "cursor ide mcp" "unexpected error" ;;
esac

# --- Disable vercel/webflow via Cursor CLI if available ---
if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would disable vercel/webflow via Cursor CLI (if available)"
elif command -v agent &>/dev/null; then
    for server in vercel webflow; do
        if agent mcp disable "$server" 2>&1; then
            log_ok "$server disabled in Cursor"
        else
            log_error "Failed to disable $server in Cursor"
            write_summary ERROR "cursor ide mcp" "failed to disable $server"
        fi
    done
else
    log "Cursor CLI (agent) not found -- disable vercel/webflow manually:"
    log "  Cursor Settings > Features > MCP > toggle off vercel and webflow"
    log "  Or install Cursor CLI: aitools install"
fi

# Only suggest restart if config actually changed
if [ "$MCP_CHANGED" = "true" ]; then
    write_summary ACTION "" "Restart Cursor IDE to apply MCP changes"
fi

# --- Exit ---
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
