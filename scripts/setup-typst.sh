#!/usr/bin/env bash
# setup-typst.sh -- Installs/updates Typst (document typesetting / PDF compiler)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). Removes non-preferred installs (cargo, npm).
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-typst"

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
    cargo uninstall typst-cli >/dev/null 2>&1 || true
fi
# npm typst is a third-party wrapper, not official
if command -v npm &>/dev/null; then
    # Cleanup: npm package may not be installed; non-blocking -- Homebrew install follows
    npm uninstall -g typst >/dev/null 2>&1 || true
fi

# --- Install/update ---
if command -v typst &>/dev/null; then
    typst_path=$(command -v typst)
    if [[ "$typst_path" == /opt/homebrew/* ]] || [[ "$typst_path" == /usr/local/* ]]; then
        log "Already installed via Homebrew -- upgrading..."
        UPGRADE_OUTPUT=$(brew upgrade typst 2>&1) || true
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
            log_ok "Typst already up to date"
            write_summary OK "typst" "$(typst --version)"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                log_error "brew upgrade typst failed (see log above)"
                write_summary ERROR "typst" "brew upgrade failed"
            else
                log_ok "$(typst --version)"
                write_summary OK "typst" "$(typst --version)"
            fi
        fi
    else
        log_warn "Typst installed via non-preferred method at $typst_path"
        log "Migrating to Homebrew..."
        if ! brew install typst 2>&1 | while IFS= read -r line; do log "$line"; done; then
            log_error "brew install typst failed"
            write_summary ERROR "typst" "brew install failed"
        fi
        if command -v typst &>/dev/null; then
            log_ok "Migrated to Homebrew: $(typst --version)"
            write_summary OK "typst" "$(typst --version)"
        else
            log_error "brew install succeeded but 'typst' not found in PATH"
            write_summary ERROR "typst" "installed but not on PATH"
        fi
    fi
else
    log "Installing Typst via Homebrew..."
    if ! brew install typst 2>&1 | while IFS= read -r line; do log "$line"; done; then
        log_error "brew install typst failed"
        write_summary ERROR "typst" "brew install failed"
    fi
    if command -v typst &>/dev/null; then
        log_ok "Typst installed ($(typst --version))"
        write_summary OK "typst" "$(typst --version)"
    else
        log_error "brew install completed but 'typst' not found in PATH"
        write_summary ERROR "typst" "installed but not on PATH"
    fi
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
