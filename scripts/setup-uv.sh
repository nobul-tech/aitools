#!/usr/bin/env bash
# setup-uv.sh -- Installs/updates uv (fast Python package installer)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). An existing non-Homebrew uv is kept (WARN)
#        when Homebrew is unavailable or its install fails -- the tool still works.
# Linux: Homebrew-only until Linux support lands (nobul-tech/aitools#14).
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
        # The exit code is kept (C-F2); the output grep stays for brew upgrade (Standard 3)
        UPGRADE_RC=0
        UPGRADE_OUTPUT=$(brew upgrade uv 2>&1) || UPGRADE_RC=$?
        if [ "$UPGRADE_RC" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'already installed\|up.to.date\|No available upgrade' >/dev/null; then
            log_ok "uv already up to date"
            UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
            write_summary OK "uv" "$UV_VERSION"
        elif [ "$UPGRADE_RC" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'error\|fatal' >/dev/null; then
            # The installed uv still works: a warning, not an error (Standard 3).
            # error_reason logs the output as detail lines.
            # 2>/dev/null: version probe only; falls back to a placeholder string
            UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
            write_warn "uv" "brew upgrade failed: $(error_reason "$UPGRADE_OUTPUT" "$UPGRADE_RC")"
            write_summary OK "uv" "$UV_VERSION"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
            log_ok "$UV_VERSION"
            write_summary OK "uv" "$UV_VERSION"
        fi
    else
        # 2>/dev/null: version probe only; falls back to a placeholder string
        UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
        if ! command -v brew >/dev/null 2>&1; then
            # The existing uv works; without Homebrew there is nothing to migrate to
            write_warn "uv" "uv at $uv_path is not a Homebrew install and Homebrew is not available -- keeping it"
            write_summary OK "uv" "$UV_VERSION"
        else
            write_warn "uv" "installed via a non-preferred method at $uv_path -- installing the Homebrew copy"
            log "Installing via Homebrew (will take precedence on PATH)..."
            # brew's output streams to the console and deploy.log as it arrives and is
            # teed to a temporary file for the reason (a failed install's output is then
            # in deploy.log twice: logging.md 8.2). The || records the pipeline status
            # (pipefail) so set -e does not abort before it is reported.
            INSTALL_OUTPUT=""
            INSTALL_RC=0
            # A failed mktemp is checked on the next line: the install then streams uncaptured
            INSTALL_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-uv.XXXXXX") || INSTALL_FILE=""
            if [ -n "$INSTALL_FILE" ]; then
                brew install uv 2>&1 | tee "$INSTALL_FILE" | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
                INSTALL_OUTPUT=$(cat "$INSTALL_FILE")
                rm -f "$INSTALL_FILE"
            else
                log_detail "mktemp failed -- the brew install output is not captured; the reason falls back to its exit code"
                brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
            fi
            BREW_UV="$(brew --prefix)/bin/uv"
            if [ "$INSTALL_RC" -eq 0 ] && [ -x "$BREW_UV" ]; then
                # 2>/dev/null: version probe only; falls back to a placeholder string
                UV_VERSION=$("$BREW_UV" --version 2>/dev/null || echo "version unknown")
                log_ok "uv installed via Homebrew ($UV_VERSION)"
                write_summary OK "uv" "$UV_VERSION"
            else
                # The pre-existing uv still works, so this is a warning, not a failure
                if [ "$INSTALL_RC" -ne 0 ]; then
                    keep_reason="$(error_reason "$INSTALL_OUTPUT" "$INSTALL_RC")"
                else
                    keep_reason="brew exited 0 but $BREW_UV is not executable"
                fi
                write_warn "uv" "brew install failed, keeping $uv_path ($UV_VERSION): $keep_reason"
                write_summary OK "uv" "$UV_VERSION"
            fi
        fi
    fi
elif ! command -v brew >/dev/null 2>&1; then
    write_error "uv" "cannot install uv" "uv is not installed and Homebrew is not available"
else
    log "Installing uv via Homebrew..."
    # Streamed and teed, as above
    INSTALL_OUTPUT=""
    INSTALL_RC=0
    # A failed mktemp is checked on the next line: the install then streams uncaptured
    INSTALL_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-uv.XXXXXX") || INSTALL_FILE=""
    if [ -n "$INSTALL_FILE" ]; then
        brew install uv 2>&1 | tee "$INSTALL_FILE" | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
        INSTALL_OUTPUT=$(cat "$INSTALL_FILE")
        rm -f "$INSTALL_FILE"
    else
        log_detail "mktemp failed -- the brew install output is not captured; the error reason falls back to its exit code"
        brew install uv 2>&1 | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
    fi
    if [ "$INSTALL_RC" -ne 0 ]; then
        write_error "uv" "brew install failed" "$(error_reason "$INSTALL_OUTPUT" "$INSTALL_RC")"
    fi
    if command -v uv >/dev/null 2>&1; then
        UV_VERSION=$(uv --version 2>/dev/null || echo "version unknown")
        log_ok "uv installed ($UV_VERSION)"
        write_summary OK "uv" "$UV_VERSION"
    elif [ "$INSTALL_RC" -ne 0 ]; then
        # One failure, one red line: the install error above is the cause
        log "uv not on PATH after the failed brew install"
    else
        write_error "uv" "installed but not on PATH" "command -v uv found nothing after brew install"
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
