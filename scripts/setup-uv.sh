#!/usr/bin/env bash
# setup-uv.sh -- Installs/updates uv (fast Python package installer)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred).
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-uv"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }
write_summary() {
    [ -n "${AITOOLS_SUMMARY_FILE:-}" ] && printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
}

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Install/update ---
if command -v uv >/dev/null 2>&1; then
    uv_path=$(command -v uv)
    if [[ "$uv_path" == /opt/homebrew/* ]] || [[ "$uv_path" == /usr/local/* ]]; then
        log "uv already installed via Homebrew -- upgrading..."
        UPGRADE_OUTPUT=$(brew upgrade uv 2>&1) || true
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
            log_ok "uv already up to date"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                log_error "brew upgrade uv failed (see log above)"
                write_summary ERROR "uv" "brew upgrade failed"
            fi
        fi
        UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
        log_ok "$UV_VERSION"
        write_summary OK "uv" "$UV_VERSION"
    else
        log_warn "uv installed via non-preferred method at $uv_path"
        log "Installing via Homebrew (will take precedence on PATH)..."
        if ! brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done; then
            log_error "brew install uv failed"
            write_summary ERROR "uv" "brew install failed"
        fi
        if command -v uv >/dev/null 2>&1; then
            UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
            log_ok "uv installed via Homebrew ($UV_VERSION)"
            write_summary OK "uv" "$UV_VERSION"
        else
            log_error "brew install completed but 'uv' not found in PATH"
            write_summary ERROR "uv" "installed but not on PATH"
        fi
    fi
else
    log "Installing uv via Homebrew..."
    if ! brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done; then
        log_error "brew install uv failed"
        write_summary ERROR "uv" "brew install failed"
    fi
    if command -v uv >/dev/null 2>&1; then
        UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
        log_ok "uv installed ($UV_VERSION)"
        write_summary OK "uv" "$UV_VERSION"
    else
        log_error "brew install completed but 'uv' not found in PATH"
        write_summary ERROR "uv" "installed but not on PATH"
    fi
fi

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $(display_path "$LOG_FILE")"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
