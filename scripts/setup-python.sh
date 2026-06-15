#!/usr/bin/env bash
# setup-python.sh -- Manages Python via uv (unified manager, macOS/Linux)
# Safe to re-run -- idempotent.
#
# uv is the single source of truth for Python on BOTH macOS and Windows. This
# script installs the target Python via uv and makes it the default, so bare
# `python`/`python3` resolve to the uv-managed interpreter (shims in uv's bin
# dir, typically ~/.local/bin). Per-repo overrides use uv's normal mechanism
# (.python-version / `uv venv` / `uv run`) -- not a global rebind.
#
# Requires uv -- setup-uv.sh MUST run before this script.
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

# Target Python version (bump here for future upgrades; mirrors setup-python.ps1)
TARGET_PY_VERSION="3.14"

# --- Require uv (the manager) ---
hash -r 2>/dev/null || true
if ! command -v uv >/dev/null 2>&1; then
    log_error "uv not found -- setup-uv.sh must run before setup-python.sh"
    write_summary ERROR "python" "uv not installed (ordering: uv before python)"
    exit 1
fi

# --- Install/update the default Python via uv ---
# --default: install unversioned python/python3 executables into uv's bin dir.
# --preview-features python-install-default: silence the experimental warning and
#   pin the behavior (the --default flag is gated behind this preview feature).
log "Installing/updating uv-managed Python $TARGET_PY_VERSION as default..."
INSTALL_RC=0
INSTALL_OUTPUT=$(uv python install "$TARGET_PY_VERSION" --default --upgrade \
    --preview-features python-install-default 2>&1) || INSTALL_RC=$?
printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do
    [ -n "$line" ] && log "$line"
done
if [ "$INSTALL_RC" -ne 0 ]; then
    log_error "uv python install failed (see log above)"
    write_summary ERROR "python" "uv python install failed"
    exit 1
fi

# --- Verify python3 resolves to the uv-managed interpreter ---
hash -r 2>/dev/null || true
if command -v python3 >/dev/null 2>&1; then
    PY_PATH=$(command -v python3)
    PY_VERSION=$(python3 --version 2>&1 || echo "version unknown")
    case "$PY_PATH" in
        *"/uv/"*|"$HOME/.local/bin/"*)
            log_ok "$PY_VERSION (uv-managed at $PY_PATH)"
            write_summary OK "python" "$PY_VERSION (uv)" ;;
        *)
            # python3 found, but not the uv shim -- PATH ordering issue
            log_warn "python3 resolves to $PY_PATH ($PY_VERSION), not the uv shim"
            log_warn "Ensure uv's bin dir (~/.local/bin) precedes /usr/bin in PATH"
            write_summary WARN "python" "$PY_VERSION (uv shim shadowed -- check PATH)"
            write_summary ACTION "" "Put ~/.local/bin before /usr/bin in PATH -- python3 default" ;;
    esac
else
    log_error "python3 not found after uv install -- is uv's bin dir (~/.local/bin) on PATH?"
    write_summary ERROR "python" "python3 not on PATH after uv install"
    write_summary ACTION "" "Add ~/.local/bin to PATH -- uv python shims"
fi

# --- pip note ---
# uv-managed CPython bundles pip; prefer `uv pip` for project work.
if command -v pip3 >/dev/null 2>&1; then
    log_ok "pip available: $(pip3 --version 2>/dev/null || echo 'version unknown')"
else
    log "pip not on PATH as a standalone command -- use 'uv pip' or 'python3 -m pip'"
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
