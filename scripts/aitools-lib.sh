# aitools-lib.sh -- shared helpers for all aitools bash scripts
# Sourced, not executed directly. No shebang, no set -euo pipefail (caller sets it).
#
# Provides: platform detection, display_path, read_config_key, logging_init,
# log/log_ok/log_error/log_warn, write_summary, show_summary.
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
#   logging_init "script-name"
#
# Entry points (aitools, aitools-install) override log functions after sourcing
# for specialized logging (file-only, JSONL, etc.).

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
IS_MACOS=false
IS_WINDOWS=false
case "$(uname -s)" in
    Darwin*)              IS_MACOS=true ;;
    MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;;
esac

# ---------------------------------------------------------------------------
# Log directory (platform-aware)
# ---------------------------------------------------------------------------
AITOOLS_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
$IS_MACOS && AITOOLS_LOG_DIR="$HOME/Library/Logs/aitools"

# ---------------------------------------------------------------------------
# Display-friendly path (native Windows on MSYS, no-op elsewhere)
# ---------------------------------------------------------------------------
display_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

# ---------------------------------------------------------------------------
# Config reader (pure bash, handles UTF-8 BOM)
# ---------------------------------------------------------------------------
# Read a top-level string value from a JSON config file.
# Handles UTF-8 BOM (PowerShell 5.x writes one) and JSON-escaped backslashes.
read_config_key() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    local val
    val=$(tr -d '\357\273\277' < "$file" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | cut -d'"' -f4)
    [ -n "$val" ] || return 1
    # Unescape JSON backslashes: \\ -> \
    printf '%b' "$val"
}

# ---------------------------------------------------------------------------
# Logging init
# ---------------------------------------------------------------------------
# Sets SCRIPT_NAME, LOG_DIR, LOG_FILE, ERRORS, creates log dir.
# Usage: logging_init "setup-foo"
logging_init() {
    SCRIPT_NAME="${1:?logging_init requires a script name}"
    LOG_DIR="$AITOOLS_LOG_DIR"
    LOG_FILE="$LOG_DIR/deploy.log"
    mkdir -p "$LOG_DIR"
    ERRORS=0
}

# ---------------------------------------------------------------------------
# Standard logging (Pattern A: tee to stdout + log file)
# ---------------------------------------------------------------------------
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }

# ---------------------------------------------------------------------------
# Summary writer (3-arg: category, tool, detail)
# ---------------------------------------------------------------------------
write_summary() {
    [ -n "${AITOOLS_SUMMARY_FILE:-}" ] && printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
}

# ---------------------------------------------------------------------------
# Summary panel renderer
# ---------------------------------------------------------------------------
# Reads AITOOLS_SUMMARY_FILE, displays colored panel, cleans up.
# Silent no-op if file unset, missing, or empty.
show_summary() {
    local sfile="${AITOOLS_SUMMARY_FILE:-}"
    [ -n "$sfile" ] || return 0
    [ -f "$sfile" ] || return 0
    [ -s "$sfile" ] || { rm -f "$sfile"; return 0; }
    echo ""
    echo "────────────────────────────────────────────────────────"
    while IFS='|' read -r cat tool detail; do
        [ "$cat" = "OK"   ] && printf '\033[32m  [ok]  %-16s %s\033[0m\n' "$tool" "$detail"
    done < "$sfile"
    while IFS='|' read -r cat tool detail; do
        [ "$cat" = "WARN" ] && printf '\033[33m  [!]   %-16s %s\033[0m\n' "$tool" "$detail"
    done < "$sfile"
    while IFS='|' read -r cat tool detail; do
        [ "$cat" = "ERROR" ] && printf '\033[31m  [ERR] %-16s %s\033[0m\n' "$tool" "$detail"
    done < "$sfile"
    local first_action=true
    while IFS='|' read -r cat tool detail; do
        if [ "$cat" = "ACTION" ]; then
            if [ "$first_action" = true ]; then
                echo ""
                printf '\033[1;35m  ACTION REQUIRED -- run before tools are ready:\033[0m\n'
                first_action=false
            fi
            printf '\033[1;35m  >>  %s\033[0m\n' "$detail"
        fi
    done < "$sfile"
    echo "────────────────────────────────────────────────────────"
    rm -f "$sfile"
}
