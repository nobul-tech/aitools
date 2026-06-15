#!/usr/bin/env bash
# setup-modal.sh — Installs/updates Modal CLI
# Safe to re-run — detects existing install and upgrades as needed.
#
# macOS/Linux: Uses uv tool (preferred) or pip --user (fallback). Requires Python 3.10+.
#
# Authentication (modal setup) is interactive and must be run separately
# after install — not automated by this script.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-modal"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# Refresh PATH hash to pick up tools installed by prior steps (e.g., setup-python, setup-uv)
hash -r

# Verify Python 3.10+ -- but ONLY as a gate for the pip fallback. When uv is
# available (the preferred path), uv provisions its own Python for the tool, so
# the system python3 version is irrelevant. On macOS, bare `python3` is often
# Apple's CommandLineTools 3.9, which would otherwise wrongly fail this check
# even though Homebrew/uv provide a newer Python.
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
fi

if command -v uv >/dev/null 2>&1; then
    log "uv available -- uv provisions Python for Modal (system Python version not required)"
elif [ -n "$PYTHON_CMD" ]; then
    PY_VERSION=$("$PYTHON_CMD" -c "import sys; print(str(sys.version_info.major) + '.' + str(sys.version_info.minor))" 2>/dev/null)
    PY_MAJOR=$(printf '%s' "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(printf '%s' "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
        log_error "Python 3.10+ required (pip fallback path). Found Python $PY_VERSION"
        write_summary ERROR "modal cli" "Python 3.10+ required (found $PY_VERSION)"
        exit 1
    fi
    log "Python $PY_VERSION found ($PYTHON_CMD)"
fi

# --- Install/update ---
if command -v uv >/dev/null 2>&1; then
    if command -v modal >/dev/null 2>&1; then
        MODAL_VERSION=$(modal --version 2>/dev/null || echo "version unknown")
        log "Modal CLI already installed ($MODAL_VERSION) -- upgrading via uv..."
        TOOL_OUTPUT=$(uv tool upgrade modal 2>&1) || true
        if printf '%s\n' "$TOOL_OUTPUT" | grep -q 'is not installed'; then
            log_warn "Modal was not installed via uv -- migrating to uv tool..."
            TOOL_OUTPUT=$(uv tool install modal 2>&1) || true
        elif printf '%s\n' "$TOOL_OUTPUT" | grep -q 'missing a valid environment'; then
            if repair_uv_tool_env "modal" "$TOOL_OUTPUT"; then
                TOOL_OUTPUT="Repaired"
            fi
        fi
        printf '%s\n' "$TOOL_OUTPUT" | while IFS= read -r line; do log "$line"; done
        if printf '%s\n' "$TOOL_OUTPUT" | grep -qi 'error\|failed'; then
            log_error "uv tool install/upgrade modal failed (see log above)"
            write_summary ERROR "modal cli" "uv tool install/upgrade failed"
        elif command -v modal >/dev/null 2>&1; then
            MODAL_VERSION=$(modal --version 2>/dev/null || echo "version unknown")
            log_ok "Modal CLI upgraded ($MODAL_VERSION)"
            write_summary OK "modal cli" "$MODAL_VERSION"
        fi
    else
        log "Installing Modal CLI via uv tool..."
        TOOL_OUTPUT=$(uv tool install modal 2>&1) || true
        printf '%s\n' "$TOOL_OUTPUT" | while IFS= read -r line; do log "$line"; done
        if printf '%s\n' "$TOOL_OUTPUT" | grep -qi 'error\|failed'; then
            log_error "uv tool install modal failed (see log above)"
            write_summary ERROR "modal cli" "uv tool install failed"
        elif command -v modal >/dev/null 2>&1; then
            MODAL_VERSION=$(modal --version 2>/dev/null || echo "version unknown")
            log_ok "Modal CLI installed ($MODAL_VERSION)"
            write_summary OK "modal cli" "$MODAL_VERSION"
        else
            log_error "uv tool install completed but 'modal' not found in PATH"
            log_warn "Ensure ~/.local/bin is in PATH"
            write_summary ERROR "modal cli" "installed but not on PATH"
        fi
    fi
elif command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
    PIP_CMD=$(command -v pip3 || command -v pip)
    log "uv not found -- installing Modal CLI via pip (--user)..."
    PIP_OUTPUT=$("$PIP_CMD" install --user modal 2>&1) || true
    printf '%s\n' "$PIP_OUTPUT" | while IFS= read -r line; do log "$line"; done
    if printf '%s\n' "$PIP_OUTPUT" | grep -qi '^ERROR:'; then
        log_error "pip install --user modal failed (see log above)"
        write_summary ERROR "modal cli" "pip install failed"
    elif command -v modal >/dev/null 2>&1; then
        MODAL_VERSION=$(modal --version 2>/dev/null || echo "version unknown")
        log_ok "Modal CLI installed ($MODAL_VERSION)"
        write_summary OK "modal cli" "$MODAL_VERSION"
    else
        log_error "pip install completed but 'modal' not found in PATH"
        write_summary ERROR "modal cli" "installed but not on PATH"
    fi
else
    log_error "No package installer found. Install uv or pip first."
    write_summary ERROR "modal cli" "no package installer (uv/pip) found"
fi

# Only suggest auth if modal is installed but not yet authenticated
if command -v modal >/dev/null 2>&1; then
    if [ ! -f "$HOME/.modal.toml" ]; then
        log_warn "Authentication required: run 'modal setup' to authenticate (browser flow)"
        write_summary WARN "modal cli" "not authenticated"
        write_summary ACTION "" "modal setup -- authenticate modal (browser flow)"
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
