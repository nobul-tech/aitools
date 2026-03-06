#!/usr/bin/env bash
# setup-datadog.sh -- Installs/updates Datadog CLI (pup) on macOS
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew tap datadog/pack (preferred).
#        Falls back to go install if Homebrew fails.
# Windows: Uses go install -- see setup-datadog.ps1.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-datadog"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

FRESH_INSTALL=false

# --- Detect existing install ---
PUP_PATH=$(command -v pup 2>/dev/null) || PUP_PATH=""

if [ -n "$PUP_PATH" ]; then
    # Check if installed via Homebrew
    if brew list datadog/pack/pup >/dev/null 2>&1; then
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log "Pup already installed via Homebrew ($PUP_VERSION) -- upgrading..."
        # brew upgrade exits non-zero when already up-to-date on some versions
        UPGRADE_OUTPUT=$(brew upgrade datadog/pack/pup 2>&1) || true
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
            log_ok "Pup already up to date"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                log_error "brew upgrade datadog/pack/pup failed (see log above)"
                write_summary ERROR "datadog cli" "brew upgrade failed"
            else
                log_ok "Pup upgraded"
            fi
        fi
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        if [ "$ERRORS" -eq 0 ]; then
            write_summary OK "datadog cli" "$PUP_VERSION"
        fi
    else
        # Installed via go install or other method
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log "Pup found at $PUP_PATH ($PUP_VERSION) -- not via Homebrew"
        log "Upgrading via go install..."
        if command -v go >/dev/null 2>&1; then
            if GO_OUTPUT=$(go install github.com/DataDog/pup@latest 2>&1); then
                PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
                log_ok "Pup upgraded via go install ($PUP_VERSION)"
                write_summary OK "datadog cli" "$PUP_VERSION (go install)"
            else
                printf '%s\n' "$GO_OUTPUT" | while IFS= read -r line; do log "$line"; done
                log_error "go install pup@latest failed"
                write_summary ERROR "datadog cli" "go install failed"
            fi
        else
            log_warn "go not found -- cannot upgrade pup via go install"
            write_summary WARN "datadog cli" "$PUP_VERSION (upgrade skipped)"
        fi
    fi
else
    # Fresh install
    FRESH_INSTALL=true
    log "Installing Pup via Homebrew (datadog/pack tap)..."
    # brew install can exit non-zero for non-fatal warnings; check output for real errors
    INSTALL_OUTPUT=$(brew install datadog/pack/pup 2>&1) || true
    printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do log "$line"; done
    if printf '%s\n' "$INSTALL_OUTPUT" | grep -qi 'error\|fatal'; then
        log_warn "brew install datadog/pack/pup failed -- trying go install fallback..."
        if command -v go >/dev/null 2>&1; then
            if GO_OUTPUT=$(go install github.com/DataDog/pup@latest 2>&1); then
                log_ok "Pup installed via go install fallback"
            else
                printf '%s\n' "$GO_OUTPUT" | while IFS= read -r line; do log "$line"; done
                log_error "go install pup@latest also failed"
                write_summary ERROR "datadog cli" "install failed (brew + go)"
            fi
        else
            log_error "go not found -- no fallback available"
            write_summary ERROR "datadog cli" "install failed (no go fallback)"
        fi
    fi
    # Re-check after install
    if command -v pup >/dev/null 2>&1; then
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log_ok "Pup installed ($PUP_VERSION)"
        if [ "$ERRORS" -eq 0 ]; then
            write_summary OK "datadog cli" "$PUP_VERSION"
        fi
    elif [ "$ERRORS" -eq 0 ]; then
        log_error "Install completed but 'pup' not found in PATH"
        write_summary ERROR "datadog cli" "installed but not on PATH"
    fi
fi

# --- Auth reminder on fresh install ---
if [ "$FRESH_INSTALL" = true ] && [ "$ERRORS" -eq 0 ]; then
    write_summary ACTION "" "Run: pup auth login (one-time OAuth)"
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
