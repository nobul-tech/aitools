#!/usr/bin/env bash
# setup-user-claude.sh — Creates user-level ~/.claude/CLAUDE.md on macOS/Linux
# Safe to re-run — replaces existing file with latest version.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-user-claude"
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_PATH="${1:-$SCRIPT_DIR/../shared/claude-shared.md}"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# Verify shared file exists
if [ ! -f "$SHARED_PATH" ]; then
    log_error "Shared preferences not found at: $(display_path "$SHARED_PATH")"
    exit 1
fi

# Backup and remove existing file so we always write the latest version
backup_file "$CLAUDE_MD"
if [ -f "$CLAUDE_MD" ]; then
    rm "$CLAUDE_MD"
    log "Removed existing $(display_path "$CLAUDE_MD")"
fi

# Read shared preferences and write inline (Cursor doesn't resolve @import)
SHARED_CONTENT=$(cat "$SHARED_PATH")

cat > "$CLAUDE_MD" << EOF
${SHARED_CONTENT}

## Machine-Specific

- Machine: $(uname -s) $(uname -m) ($(hostname -s 2>/dev/null || hostname))
- Shell: $(basename "$SHELL")
EOF

log_ok "Wrote $(display_path "$CLAUDE_MD")"
log "Inlined shared preferences from: $(display_path "$SHARED_PATH")"

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
