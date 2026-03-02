#!/usr/bin/env bash
# setup-typst.sh -- Installs/updates Typst (document typesetting / PDF compiler)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). Removes non-preferred installs (cargo, npm).
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-typst"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Cleanup non-preferred installs ---
# Cargo typst-cli conflicts with Homebrew typst (different binary paths)
if command -v cargo &>/dev/null; then
    # Cleanup: cargo package may not be installed; non-blocking -- Homebrew install follows
    cargo uninstall typst-cli 2>/dev/null || true
fi
# npm typst is a third-party wrapper, not official
if command -v npm &>/dev/null; then
    # Cleanup: npm package may not be installed; non-blocking -- Homebrew install follows
    npm uninstall -g typst 2>/dev/null || true
fi

# --- Install/update ---
if command -v typst &>/dev/null; then
    typst_path=$(command -v typst)
    if [[ "$typst_path" == /opt/homebrew/* ]] || [[ "$typst_path" == /usr/local/* ]]; then
        log "Already installed via Homebrew -- upgrading..."
        # brew upgrade outputs progress to stderr; returns non-zero when already up to date
        brew upgrade typst 2>/dev/null || log_ok "Typst already up to date"
        log_ok "$(typst --version)"
    else
        log_warn "Typst installed via non-preferred method at $typst_path"
        log "Migrating to Homebrew..."
        brew install typst
        if command -v typst &>/dev/null; then
            log_ok "Migrated to Homebrew: $(typst --version)"
        else
            log_error "brew install succeeded but 'typst' not found in PATH"
        fi
    fi
else
    log "Installing Typst via Homebrew..."
    brew install typst
    if command -v typst &>/dev/null; then
        log_ok "Typst installed ($(typst --version))"
    else
        log_error "brew install completed but 'typst' not found in PATH"
    fi
fi

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
