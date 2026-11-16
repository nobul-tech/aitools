#!/usr/bin/env bash
# setup-modal.sh — Installs/updates Modal CLI
# Safe to re-run — detects existing install and upgrades as needed.
#
# macOS/Linux: Uses uv tool (preferred) or pip --user (fallback). Requires Python 3.10+.
#
# Authentication (modal setup) is interactive and must be run separately
# after install — not automated by this script.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
        # error_reason logs the output as detail lines
        write_error "modal cli" "Python version check failed" "$(error_reason "$PY_VERSION" "$py_rc")"
        exit 1
    fi
    PY_MAJOR=$(printf '%s' "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(printf '%s' "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
        write_error "modal cli" "Python 3.10+ required" "found Python $PY_VERSION (pip fallback path)"
        exit 1
    fi
    log "Python $PY_VERSION found ($PYTHON_CMD)"
fi

# --- Install/update ---
# Exit codes decide (C-F2). A command's output goes to the log as detail; a failed
# command's output is passed to error_reason instead, which logs it (logging.md 8.2).
if command -v uv >/dev/null 2>&1; then
    if command -v modal >/dev/null 2>&1; then
        read_modal_version
        log "Modal CLI already installed ($MODAL_VERSION) -- upgrading via uv..."
        tool_rc=0
        TOOL_OUTPUT=$(uv tool upgrade modal 2>&1) || tool_rc=$?
        # repair_uv_tool_env: 0 repaired, 1 not applicable, 3 failed and already recorded
        repair_rc=1
        if [ "$tool_rc" -eq 0 ]; then
            write_output_detail "uv-tool-upgrade" "$TOOL_OUTPUT"
        elif grep -q 'is not installed' <<< "$TOOL_OUTPUT"; then
            write_output_detail "uv-tool-upgrade (exit $tool_rc)" "$TOOL_OUTPUT"
            write_warn "modal cli" "not installed with uv -- migrating to uv tool"
            tool_rc=0
            TOOL_OUTPUT=$(uv tool install modal 2>&1) || tool_rc=$?
            if [ "$tool_rc" -eq 0 ]; then write_output_detail "uv-tool-install" "$TOOL_OUTPUT"; fi
        else
            repair_rc=0
            repair_uv_tool_env "modal" "$TOOL_OUTPUT" "modal cli" || repair_rc=$?
            if [ "$repair_rc" -ne 1 ]; then write_output_detail "uv-tool-upgrade (exit $tool_rc)" "$TOOL_OUTPUT"; fi
            if [ "$repair_rc" -eq 0 ]; then tool_rc=0; fi
        fi
        if [ "$tool_rc" -ne 0 ]; then
            # A failed repair (3) is already recorded by the library: no second record
            if [ "$repair_rc" -ne 3 ]; then
                write_error "modal cli" "uv tool install/upgrade failed" "$(error_reason "$TOOL_OUTPUT" "$tool_rc")"
            fi
        elif command -v modal >/dev/null 2>&1; then
            read_modal_version
            log_ok "Modal CLI upgraded ($MODAL_VERSION)"
            write_summary OK "modal cli" "$MODAL_VERSION"
        else
            write_error "modal cli" "not on PATH after upgrade" "modal not found on PATH after uv tool upgrade"
        fi
    else
        log "Installing Modal CLI via uv tool..."
        tool_rc=0
        TOOL_OUTPUT=$(uv tool install modal 2>&1) || tool_rc=$?
        if [ "$tool_rc" -ne 0 ]; then
            write_error "modal cli" "uv tool install failed" "$(error_reason "$TOOL_OUTPUT" "$tool_rc")"
        else
            write_output_detail "uv-tool-install" "$TOOL_OUTPUT"
            if command -v modal >/dev/null 2>&1; then
                read_modal_version
                log_ok "Modal CLI installed ($MODAL_VERSION)"
                write_summary OK "modal cli" "$MODAL_VERSION"
            else
                # Not on PATH is an error, with the remedy as an ACTION (Standard 4)
                write_error "modal cli" "installed but not on PATH" "modal not found after uv tool install"
                write_summary ACTION "" "Add the directory 'uv tool dir --bin' prints to PATH -- modal not accessible"
            fi
        fi
    fi
elif command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
    PIP_CMD=$(command -v pip3 || command -v pip)
    log "uv not found -- installing Modal CLI via pip (--user)..."
    pip_rc=0
    PIP_OUTPUT=$("$PIP_CMD" install --user modal 2>&1) || pip_rc=$?
    if [ "$pip_rc" -ne 0 ]; then
        write_error "modal cli" "pip install failed" "$(error_reason "$PIP_OUTPUT" "$pip_rc")"
    else
        write_output_detail "pip-install" "$PIP_OUTPUT"
        if command -v modal >/dev/null 2>&1; then
            read_modal_version
            log_ok "Modal CLI installed ($MODAL_VERSION)"
            write_summary OK "modal cli" "$MODAL_VERSION"
        else
            write_error "modal cli" "installed but not on PATH" "modal not found after pip install --user"
        fi
    fi
else
    write_error "modal cli" "no package installer" "neither uv nor pip is on PATH"
fi

# Only suggest auth if modal is installed, this run had no error, and modal is not yet
# authenticated
if command -v modal >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    if [ ! -f "$HOME/.modal.toml" ]; then
        write_action "modal cli" "not authenticated -- run: modal setup (browser flow)" "modal setup -- authenticate modal (browser flow)"
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
