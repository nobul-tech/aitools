#!/usr/bin/env bash
# setup-python.sh -- Installs/updates Python via Homebrew
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). pip is bundled with Python.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-python"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Detect Homebrew Python ---
# Check known Homebrew paths directly (avoids shims like pyenv shadowing PATH)
BREW_PY=""
for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    if [ -x "$candidate" ]; then
        BREW_PY="$candidate"
        break
    fi
done

# --- Install/update ---
if [ -n "$BREW_PY" ]; then
    PY_VERSION=$("$BREW_PY" --version 2>/dev/null || echo "version unknown")
    log "Python already installed via Homebrew ($PY_VERSION) -- upgrading..."
    UPGRADE_OUTPUT=$(brew upgrade python 2>&1) || true
    if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
        log_ok "Python already up to date"
        PY_VERSION=$("$BREW_PY" --version 2>/dev/null || echo "version unknown")
        write_summary OK "python" "$PY_VERSION"
    else
        printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
            log_error "brew upgrade python failed (see log above)"
            write_summary ERROR "python" "brew upgrade failed"
        else
            PY_VERSION=$("$BREW_PY" --version 2>/dev/null || echo "version unknown")
            log_ok "$PY_VERSION"
            write_summary OK "python" "$PY_VERSION"
        fi
    fi
else
    log "Installing Python via Homebrew..."
    if ! brew install python 2>&1 | while IFS= read -r line; do log "$line"; done; then
        log_error "brew install python failed"
        write_summary ERROR "python" "brew install failed"
    fi
    # Re-check after install
    for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3; do
        if [ -x "$candidate" ]; then
            BREW_PY="$candidate"
            break
        fi
    done
    if [ -n "$BREW_PY" ]; then
        PY_VERSION=$("$BREW_PY" --version 2>/dev/null || echo "version unknown")
        log_ok "Python installed ($PY_VERSION)"
        write_summary OK "python" "$PY_VERSION"
    else
        log_error "brew install completed but python3 not found at Homebrew paths"
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
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
