#!/usr/bin/env bash
# setup-user-mcp.sh — Installs/updates user-level MCP servers for Claude Code on macOS/Linux
# Safe to re-run — checks existing config, only re-adds when changed or --force used.
#
# All three servers at user level. Chrome DevTools enabled globally;
# Vercel and Webflow are present but disabled by default (deny rules).
# Use `aitools --addmcp` to enable per project.

# --- BEGIN mcp body (extracted by build-deploy) ---
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
SCRIPT_NAME="setup-user-mcp"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }

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

# --- Check existing MCP server configs via claude mcp list ---
# Stores parsed output as newline-separated "name=details" pairs.
# Avoids bash 4+ associative arrays for macOS compatibility (bash 3.2).
mcp_current_data=""
mcp_current_count=0

saved_claudecode="${CLAUDECODE:-}"
unset CLAUDECODE

mcp_list_rc=0
mcp_list_output=$(claude mcp list 2>/dev/null) || mcp_list_rc=$?

if [ -n "$saved_claudecode" ]; then
    export CLAUDECODE="$saved_claudecode"
fi

if [ $mcp_list_rc -eq 0 ] && [ -n "$mcp_list_output" ]; then
    mcp_current_data=$(printf '%s\n' "$mcp_list_output" | perl -ne '
        s/\e\[[0-9;]*m//g;
        next unless /^(.+?):\s+(.+)\s+-\s+.+$/;
        my ($name, $details) = ($1, $2);
        $details =~ s/\s+\(HTTP\)$//;
        $details =~ s/\s+$//;
        print "$name=$details\n";
    ')
    if [ -n "$mcp_current_data" ]; then
        mcp_current_count=$(printf '%s\n' "$mcp_current_data" | wc -l | tr -d ' ')
    fi
    log_ok "Checked existing MCP config ($mcp_current_count servers found)"
else
    log_warn "Could not check existing MCP config; will re-add all servers"
fi

# Check if a server's current config matches expected.
server_config_matches() {
    local name="$1" expected="$2"
    [ -n "$mcp_current_data" ] || return 1
    local line
    line=$(printf '%s\n' "$mcp_current_data" | grep "^${name}=" | head -1)
    [ -n "$line" ] || return 1
    local current="${line#*=}"
    [ "$current" = "$expected" ]
}

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
if [ "$FORCE" = "true" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would re-add MCP server: chrome-devtools (--force)"
    else
        add_mcp_server "chrome-devtools" chrome-devtools --scope user -- npx chrome-devtools-mcp@latest --isolated
    fi
elif server_config_matches "chrome-devtools" "npx chrome-devtools-mcp@latest --isolated"; then
    log_ok "chrome-devtools already configured, skipping (use --force to re-add)"
else
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would add MCP server: chrome-devtools (stdio, --isolated)"
    else
        add_mcp_server "chrome-devtools" chrome-devtools --scope user -- npx chrome-devtools-mcp@latest --isolated
    fi
fi

# Vercel — remote HTTP server (disabled by default via deny rules below)
if [ "$FORCE" = "true" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would re-add MCP server: vercel (--force)"
    else
        add_mcp_server "vercel" --transport http --scope user vercel https://mcp.vercel.com
    fi
elif server_config_matches "vercel" "https://mcp.vercel.com"; then
    log_ok "vercel already configured, skipping (use --force to re-add)"
else
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would add MCP server: vercel (http)"
    else
        add_mcp_server "vercel" --transport http --scope user vercel https://mcp.vercel.com
    fi
fi

# Webflow — remote HTTP server (disabled by default via deny rules below)
if [ "$FORCE" = "true" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would re-add MCP server: webflow (--force)"
    else
        add_mcp_server "webflow" --transport http --scope user webflow https://mcp.webflow.com/mcp
    fi
elif server_config_matches "webflow" "https://mcp.webflow.com/mcp"; then
    log_ok "webflow already configured, skipping (use --force to re-add)"
else
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would add MCP server: webflow (http)"
    else
        add_mcp_server "webflow" --transport http --scope user webflow https://mcp.webflow.com/mcp
    fi
fi

# --- Merge deny rules into ~/.claude/settings.json ---
# Vercel and Webflow are disabled by default at user level.
# Projects enable them via .claude/settings.local.json (aitools --addmcp).

settings_file="$HOME/.claude/settings.json"
if [ "$DRY_RUN" != "true" ]; then
    backup_file "$settings_file"
fi
log "Merging deny rules into $(display_path "$settings_file")..."

DENY_RESULT=$(node -e "
const fs = require('fs');
const path = require('path');
const f = process.argv[1];
const dryRun = process.argv[2] === 'true';
const force = process.argv[3] === 'true';
const dir = path.dirname(f);

// Ensure directory exists
if (!dryRun && !fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

// Read existing settings
let settings = {};
let corrupt = false;
try {
    settings = JSON.parse(fs.readFileSync(f, 'utf8'));
} catch (e) {
    if (e.code !== 'ENOENT') {
        corrupt = true;
        console.error('Warning: ' + f + ' is invalid JSON');
    }
}
const beforeKeys = Object.keys(settings);

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

// Clobber detection
const managedKeys = ['permissions'];
const afterKeys = Object.keys(settings);
const lostKeys = beforeKeys.filter(k => !afterKeys.includes(k));

if (dryRun) {
    console.error('[DRY RUN] ' + f + ': merge deny rules');
    console.error('  Managed fields: permissions.deny');
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
    fs.writeFileSync(f, JSON.stringify(settings, null, 2) + '\n');

    // Post-write validation
    const _v = JSON.parse(fs.readFileSync(f, 'utf8'));
    if (!_v.permissions) { console.error('Validation failed: missing permissions'); process.exit(1); }
    console.log('ok');
}
" "$settings_file" "$DRY_RUN" "$FORCE")

case "$DENY_RESULT" in
    ok)
        log_ok "Deny rules set for vercel, webflow in $(display_path "$settings_file")" ;;
    dry-run)
        log "[DRY RUN] Would set deny rules for vercel, webflow" ;;
    error-corrupt)
        log_error "$(display_path "$settings_file") is corrupt. Use --force to overwrite." ;;
    error-clobber)
        log_error "$(display_path "$settings_file") merge would lose fields. Use --force to proceed." ;;
    *)
        log_error "Unexpected deny merge result: $DENY_RESULT" ;;
esac

if [ "$DRY_RUN" != "true" ]; then
    log_ok "User-level MCP configured (all servers; vercel/webflow disabled by default)"
else
    log "[DRY RUN] Would configure user-level MCP (all servers; vercel/webflow disabled by default)"
fi
log "To enable per project: aitools --addmcp vercel"
log "To check status: aitools mcp"

# --- END mcp body (extracted by build-deploy) ---

# --- Deploy Chrome DevTools skills ---
# Vendored from https://github.com/ChromeDevTools/chrome-devtools-mcp/tree/main/skills
# These provide structured workflows for browser automation and a11y auditing.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/../shared/skills"
SKILLS_DEST="$HOME/.claude/skills"
SKILLS_DEST_CURSOR="$HOME/.cursor/skills"

deploy_skill() {
    local skill_name="$1"
    local dest_base="$2"
    local src="$SKILLS_SRC/$skill_name/SKILL.md"
    local dest_dir="$dest_base/$skill_name"
    local dest="$dest_dir/SKILL.md"

    if [ ! -f "$src" ]; then
        log_error "Skill source not found: $src"
        return
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would deploy skill: $skill_name -> $(display_path "$dest")"
    else
        mkdir -p "$dest_dir"
        cp "$src" "$dest"
        log_ok "Deployed skill: $skill_name -> $(display_path "$dest")"
    fi
}

log "Deploying Chrome DevTools skills to $(display_path "$SKILLS_DEST")..."
deploy_skill "chrome-devtools" "$SKILLS_DEST"
deploy_skill "a11y-debugging" "$SKILLS_DEST"

log "Deploying Chrome DevTools skills to $(display_path "$SKILLS_DEST_CURSOR")..."
deploy_skill "chrome-devtools" "$SKILLS_DEST_CURSOR"
deploy_skill "a11y-debugging" "$SKILLS_DEST_CURSOR"

# --- BEGIN exit (extracted by build-deploy) ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
# --- END exit (extracted by build-deploy) ---
