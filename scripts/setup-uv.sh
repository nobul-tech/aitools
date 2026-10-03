#!/usr/bin/env bash
# setup-uv.sh -- Installs/updates uv (fast Python package installer)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). An existing non-Homebrew uv is kept (WARN)
#        when Homebrew is unavailable or its install fails -- the tool still works.
# Linux: Homebrew-only until Linux support lands (nobul-tech/aitools#14).
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-uv"

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
            UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
            write_summary OK "uv" "$UV_VERSION"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                log_error "brew upgrade uv failed (see log above)"
                write_summary ERROR "uv" "brew upgrade failed"
            else
                UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
                log_ok "$UV_VERSION"
                write_summary OK "uv" "$UV_VERSION"
            fi
        fi
    else
        # 2>/dev/null: version probe only; falls back to a placeholder string
        UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
        if ! command -v brew >/dev/null 2>&1; then
            # The existing uv works; without Homebrew there is nothing to migrate to
            log_warn "uv at $uv_path ($UV_VERSION) is not a Homebrew install and Homebrew is not available -- keeping it"
            write_summary WARN "uv" "$UV_VERSION (not Homebrew)"
        else
            log_warn "uv installed via non-preferred method at $uv_path"
            log "Installing via Homebrew (will take precedence on PATH)..."
            BREW_RC=0
            # || records the pipeline status (pipefail) so set -e does not abort before it is reported
            brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done || BREW_RC=$?
            BREW_UV="$(brew --prefix)/bin/uv"
            if [ "$BREW_RC" -eq 0 ] && [ -x "$BREW_UV" ]; then
                # 2>/dev/null: version probe only; falls back to a placeholder string
                UV_VERSION=$("$BREW_UV" --version 2>/dev/null || echo "version unknown")
                log_ok "uv installed via Homebrew ($UV_VERSION)"
                write_summary OK "uv" "$UV_VERSION"
            else
                # The pre-existing uv still works, so this is a warning, not a failure
                log_warn "brew install uv failed (exit $BREW_RC) -- keeping existing uv at $uv_path ($UV_VERSION)"
                write_summary WARN "uv" "$UV_VERSION (brew failed)"
            fi
        fi
    fi
elif ! command -v brew >/dev/null 2>&1; then
    log_error "uv is not installed and Homebrew is not available -- cannot install uv"
    write_summary ERROR "uv" "Homebrew not found"
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
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
