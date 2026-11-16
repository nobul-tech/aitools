#!/usr/bin/env bash
# setup-user-mcp.sh — Installs/updates user-level MCP servers for Claude Code on macOS/Linux
# Safe to re-run — checks existing config, only re-adds when changed or --force used.
#
# Registers all three servers at user level (chrome-devtools, vercel, webflow).
# This script does NOT write ~/.claude/settings.json: permission rules
# (allow/ask/deny) are profile-sourced and reconciled by setup-user-settings.
#
# Managed: MCP server registration (via `claude mcp add`).
# Preserved: ~/.claude/settings.json (not touched here).
#
# chrome-devtools arguments depend on the environment (AITOOLS_ENVIRONMENT, aitools-lib):
#   local            npx chrome-devtools-mcp@latest --isolated
#   claude-code-web  npx -y chrome-devtools-mcp@latest --isolated --headless --chromeArg=--no-sandbox
#                    (D-CHR2, reference/tool-ops-google-chrome.md: root, no display)
# setup-user-mcp.ps1 has no such branch: Windows is never the Claude Code web
# environment (cross-platform.md "Environment branches", D-ENV4).

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

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-user-mcp"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- no files will be written"

# Check that claude CLI is available
if ! command -v claude &> /dev/null; then
    write_error "claude mcp" "MCP servers not registered" "'claude' CLI not found in PATH -- install Claude Code first: https://claude.ai/download"
    exit 1
fi

# Check that Node.js is available (required for Chrome DevTools MCP and settings merge)
if ! command -v node &> /dev/null; then
    write_error "claude mcp" "MCP servers not registered" "Node.js not found -- install it with aitools install or from https://nodejs.org"
    exit 1
else
    log_ok "Node.js $(node --version) found"
fi

# --- chrome-devtools arguments for this environment ---
if is_claude_code_web; then
    # D-CHR2: sessions run as root with no display -- Chrome headless, sandbox off.
    CHROME_MCP_CMD=(npx -y chrome-devtools-mcp@latest --isolated --headless --chromeArg=--no-sandbox)
    log "Environment: claude-code-web -- chrome-devtools runs headless with Chrome's sandbox off (D-CHR2)"
else
    CHROME_MCP_CMD=(npx chrome-devtools-mcp@latest --isolated)
fi
# `claude mcp list` prints a stdio server as its command and args joined by spaces.
CHROME_MCP_EXPECTED="${CHROME_MCP_CMD[*]}"

# --- Check existing MCP server configs via claude mcp list ---
# Stores parsed output as newline-separated "name=details" pairs.
# Avoids bash 4+ associative arrays for macOS compatibility (bash 3.2).
mcp_current_data=""
mcp_current_count=0

saved_claudecode="${CLAUDECODE:-}"
unset CLAUDECODE

# stderr goes to a temp file, not into the captured stdout: stdout is parsed by the
# `name: details - status` pattern below, and stderr text could match it.
LIST_ERR=""
# 2>/dev/null: a mktemp failure is checked on the next line (fallback /dev/null)
if ! LIST_ERR=$(mktemp 2>/dev/null); then LIST_ERR=""; fi
if [ -z "$LIST_ERR" ] || [ ! -f "$LIST_ERR" ]; then
    log_detail "mktemp failed -- the stderr of claude mcp list is not captured"
    LIST_ERR=/dev/null
fi
mcp_list_rc=0
mcp_list_output=$(claude mcp list 2>"$LIST_ERR") || mcp_list_rc=$?
mcp_list_err=""
if [ "$LIST_ERR" != "/dev/null" ]; then
    mcp_list_err=$(<"$LIST_ERR")
    rm -f "$LIST_ERR"
fi

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
    # The reason: the command's stderr, else its stdout (error_reason logs it as detail)
    write_warn "claude mcp" "could not read the MCP server list -- re-adding all servers: $(error_reason "${mcp_list_err:-$mcp_list_output}" "$mcp_list_rc")"
fi

# Check if a server's current config matches expected.
server_config_matches() {
    local name="$1" expected="$2"
    [ -n "$mcp_current_data" ] || return 1
    local line
    line=$(printf '%s\n' "$mcp_current_data" | grep "^${name}=" | sed -n '1p' || true)
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
    # Captured, not streamed, so a failure carries its reason (reference/logging.md 8.3)
    local add_rc=0 add_out="" add_line
    add_out=$(claude mcp add "$@" 2>&1) || add_rc=$?
    if [ "$add_rc" -eq 0 ]; then
        while IFS= read -r add_line; do
            if [ -n "$add_line" ]; then log_detail "claude mcp add $name: $add_line"; fi
        done <<< "$add_out"
        log_ok "$name configured"
        MCP_CHANGED=true
    else
        # error_reason logs the output as detail lines
        write_error "claude mcp" "claude mcp add $name failed" "$(error_reason "$add_out" "$add_rc")"
    fi

    # Restore CLAUDECODE
    if [ -n "$saved_claudecode" ]; then
        export CLAUDECODE="$saved_claudecode"
    fi
}

MCP_CHANGED=false
log "Setting up MCP servers for Claude Code (user scope)..."

# Chrome DevTools — local stdio server via npx
if [ "$FORCE" = "true" ]; then
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would re-add MCP server: chrome-devtools (--force)"
    else
        add_mcp_server "chrome-devtools" chrome-devtools --scope user -- "${CHROME_MCP_CMD[@]}"
    fi
elif server_config_matches "chrome-devtools" "$CHROME_MCP_EXPECTED"; then
    log_ok "chrome-devtools already configured, skipping (use --force to re-add)"
else
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would add MCP server: chrome-devtools (stdio: $CHROME_MCP_EXPECTED)"
    else
        add_mcp_server "chrome-devtools" chrome-devtools --scope user -- "${CHROME_MCP_CMD[@]}"
    fi
fi

# Vercel — remote HTTP server
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

# Webflow — remote HTTP server
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

# --- Settings.json: not managed here ---
# This script no longer writes ~/.claude/settings.json. Permission rules
# (allow/ask/deny) are profile-sourced and reconciled by setup-user-settings
# against profile.json. Obsolete deny rules (MCP(vercel)/MCP(webflow)/
# Agent(claude-code-guide)) are purged there. setup-user-mcp only registers
# MCP servers via `claude mcp add`.

if [ "$DRY_RUN" != "true" ]; then
    log_ok "User-level MCP configured (chrome-devtools, vercel, webflow)"
    if [ "$ERRORS" -eq 0 ]; then
        if [ "$MCP_CHANGED" = "true" ]; then
            write_summary OK "claude mcp" "configured"
        else
            write_summary OK "claude mcp" "verified"
        fi
    fi
else
    log "[DRY RUN] Would configure user-level MCP (chrome-devtools, vercel, webflow)"
fi
log "To check status: aitools mcp"

# Display cloud MCP servers configured at claude.ai.
# Silent no-op if claude CLI unavailable or no cloud servers found.
show_cloud_mcp_status() {
    command -v claude &>/dev/null || return 0
    local saved_claudecode="${CLAUDECODE:-}"
    unset CLAUDECODE
    local raw
    raw=$(claude mcp list 2>/dev/null) || true
    if [ -n "$saved_claudecode" ]; then export CLAUDECODE="$saved_claudecode"; fi
    [ -n "$raw" ] || return 0
    local parsed
    parsed=$(printf '%s\n' "$raw" | perl -ne '
        s/\e\[[0-9;]*m//g;
        next unless /^claude\.ai\s+(.+?):\s+.+\s+-\s+(.+)$/;
        my ($name, $status) = ($1, $2);
        $status =~ s/\s+$//;
        my $pad = length($name) < 24 ? " " x (24 - length($name)) : " ";
        printf "  %s%s%s\n", $name, $pad, $status;
    ')
    [ -n "$parsed" ] || return 0
    log "Cloud MCP servers (configured at claude.ai):"
    while IFS= read -r line; do
        log "$line"
    done <<< "$parsed"
}

# --- END mcp body (extracted by build-deploy) ---

# --- BEGIN exit (extracted by build-deploy) ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    show_cloud_mcp_status
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    show_cloud_mcp_status
    log "COMPLETED successfully" "ok"
    exit 0
fi
# --- END exit (extracted by build-deploy) ---
