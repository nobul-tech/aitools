#!/usr/bin/env bash
# setup-python.sh -- Installs/updates Python via Homebrew
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). pip is bundled with Python.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-python"
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
if command -v python3 >/dev/null 2>&1; then
    PY_VERSION=$(python3 --version 2>/dev/null || echo "version unknown")
    python3_path=$(command -v python3)
    if [[ "$python3_path" == /opt/homebrew/* ]] || [[ "$python3_path" == /usr/local/* ]]; then
        log "Python already installed via Homebrew ($PY_VERSION) -- upgrading..."
        UPGRADE_OUTPUT=$(brew upgrade python 2>&1) || true
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
            log_ok "Python already up to date"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                log_error "brew upgrade python failed (see log above)"
                write_summary ERROR "python" "brew upgrade failed"
            fi
        fi
        PY_VERSION=$(python3 --version 2>/dev/null || echo "version unknown")
        log_ok "$PY_VERSION"
        write_summary OK "python" "$PY_VERSION"
    else
        log_warn "Python installed via non-preferred method at $python3_path"
        log "Installing via Homebrew (will take precedence on PATH)..."
        if ! brew install python 2>&1 | while IFS= read -r line; do log "$line"; done; then
            log_error "brew install python failed"
            write_summary ERROR "python" "brew install failed"
        fi
        if command -v python3 >/dev/null 2>&1; then
            PY_VERSION=$(python3 --version 2>/dev/null || echo "version unknown")
            log_ok "Python installed via Homebrew ($PY_VERSION)"
            write_summary OK "python" "$PY_VERSION"
        else
            log_error "brew install completed but 'python3' not found in PATH"
            write_summary ERROR "python" "installed but not on PATH"
        fi
    fi
else
    log "Installing Python via Homebrew..."
    if ! brew install python 2>&1 | while IFS= read -r line; do log "$line"; done; then
        log_error "brew install python failed"
        write_summary ERROR "python" "brew install failed"
    fi
    if command -v python3 >/dev/null 2>&1; then
        PY_VERSION=$(python3 --version 2>/dev/null || echo "version unknown")
        log_ok "Python installed ($PY_VERSION)"
        write_summary OK "python" "$PY_VERSION"
    else
        log_error "brew install completed but 'python3' not found in PATH"
        write_summary ERROR "python" "installed but not on PATH"
    fi
fi

# --- Verify pip ---
if command -v pip3 >/dev/null 2>&1; then
    PIP_VERSION=$(pip3 --version 2>/dev/null || echo "version unknown")
    log_ok "pip bundled: $PIP_VERSION"
else
    log_warn "pip3 not found -- may need to reinstall Python or run: python3 -m ensurepip"
fi

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $(display_path "$LOG_FILE")"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
