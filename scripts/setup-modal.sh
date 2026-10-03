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

# Log captured command output to the log file as detail lines (blank lines skipped).
write_output_detail() {  # label, output
    local line
    while IFS= read -r line; do
        if [ -n "${line// /}" ]; then log_detail "$1: $line"; fi
    done <<< "$2"
}

# Set MODAL_VERSION from `modal --version`. Python warnings print before the version
# line, so the last line is kept. A failed probe logs its output and leaves "version
# unknown"; the install result is decided by the uv/pip exit code, not by this probe.
read_modal_version() {
    local out rc=0
    out=$(modal --version 2>&1) || rc=$?
    if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
        MODAL_VERSION=${out##*$'\n'}
    else
        write_output_detail "modal-version (exit $rc)" "$out"
        MODAL_VERSION="version unknown"
    fi
}

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
    py_rc=0
    PY_VERSION=$("$PYTHON_CMD" -c "import sys; print(str(sys.version_info.major) + '.' + str(sys.version_info.minor))" 2>&1) || py_rc=$?
    if [ "$py_rc" -ne 0 ] || ! [[ "$PY_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        write_output_detail "python-version (exit $py_rc)" "$PY_VERSION"
        log_error "Could not read the $PYTHON_CMD version (exit $py_rc) -- see $(display_path "$LOG_FILE")"
        write_summary ERROR "modal cli" "Python version check failed"
        exit 1
    fi
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
# Exit codes decide (C-F2); each command's full output goes to the log as detail.
if command -v uv >/dev/null 2>&1; then
    if command -v modal >/dev/null 2>&1; then
        read_modal_version
        log "Modal CLI already installed ($MODAL_VERSION) -- upgrading via uv..."
        tool_rc=0
        TOOL_OUTPUT=$(uv tool upgrade modal 2>&1) || tool_rc=$?
        write_output_detail "uv-tool-upgrade" "$TOOL_OUTPUT"
        if [ "$tool_rc" -ne 0 ] && grep -q 'is not installed' <<< "$TOOL_OUTPUT"; then
            log_warn "Modal was not installed via uv -- migrating to uv tool..."
            tool_rc=0
            TOOL_OUTPUT=$(uv tool install modal 2>&1) || tool_rc=$?
            write_output_detail "uv-tool-install" "$TOOL_OUTPUT"
        elif [ "$tool_rc" -ne 0 ] && repair_uv_tool_env "modal" "$TOOL_OUTPUT"; then
            tool_rc=0
        fi
        if [ "$tool_rc" -ne 0 ]; then
            log_error "uv tool install/upgrade modal failed (exit $tool_rc) -- see $(display_path "$LOG_FILE")"
            write_summary ERROR "modal cli" "uv tool install/upgrade failed (exit $tool_rc)"
        elif command -v modal >/dev/null 2>&1; then
            read_modal_version
            log_ok "Modal CLI upgraded ($MODAL_VERSION)"
            write_summary OK "modal cli" "$MODAL_VERSION"
        else
            log_error "uv tool upgrade completed but 'modal' not found in PATH"
            write_summary ERROR "modal cli" "not on PATH after upgrade"
        fi
    else
        log "Installing Modal CLI via uv tool..."
        tool_rc=0
        TOOL_OUTPUT=$(uv tool install modal 2>&1) || tool_rc=$?
        write_output_detail "uv-tool-install" "$TOOL_OUTPUT"
        if [ "$tool_rc" -ne 0 ]; then
            log_error "uv tool install modal failed (exit $tool_rc) -- see $(display_path "$LOG_FILE")"
            write_summary ERROR "modal cli" "uv tool install failed (exit $tool_rc)"
        elif command -v modal >/dev/null 2>&1; then
            read_modal_version
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
    pip_rc=0
    PIP_OUTPUT=$("$PIP_CMD" install --user modal 2>&1) || pip_rc=$?
    write_output_detail "pip-install" "$PIP_OUTPUT"
    if [ "$pip_rc" -ne 0 ]; then
        log_error "pip install --user modal failed (exit $pip_rc) -- see $(display_path "$LOG_FILE")"
        write_summary ERROR "modal cli" "pip install failed (exit $pip_rc)"
    elif command -v modal >/dev/null 2>&1; then
        read_modal_version
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
