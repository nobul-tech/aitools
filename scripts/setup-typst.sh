#!/usr/bin/env bash
# setup-typst.sh -- Installs/updates Typst (document typesetting / PDF compiler)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). Removes non-preferred installs (cargo, npm).
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
# Only packages that are actually installed are removed; a failed removal is a
# warning (non-blocking -- the Homebrew install below proceeds), with the output logged.
remove_package() {  # label, command...
    local label="$1"; shift
    local out rc=0 line
    out=$("$@" 2>&1) || rc=$?
    if [ "$rc" -eq 0 ]; then
        while IFS= read -r line; do
            if [ -n "${line// /}" ]; then log_detail "$label: $line"; fi
        done <<< "$out"
        log "Removed non-preferred install ($label)"
    else
        # error_reason logs the output as detail lines (logging.md 8.2)
        write_warn "typst" "$label failed: $(error_reason "$out" "$rc")"
    fi
}
# Cargo typst-cli conflicts with Homebrew typst (different binary paths)
if command -v cargo &>/dev/null; then
    cargo_list_rc=0
    cargo_list=$(cargo install --list 2>&1) || cargo_list_rc=$?
    if [ "$cargo_list_rc" -ne 0 ]; then
        write_warn "typst" "cargo install --list failed, cargo typst-cli cleanup skipped: $(error_reason "$cargo_list" "$cargo_list_rc")"
    elif printf '%s\n' "$cargo_list" | grep '^typst-cli ' >/dev/null; then
        remove_package "cargo uninstall typst-cli" cargo uninstall typst-cli
    fi
fi
# npm typst is a third-party wrapper, not official. `npm ls` exits non-zero when absent.
if command -v npm &>/dev/null && npm_typst=$(npm ls -g --depth=0 typst 2>&1); then
    log_detail "npm-ls-typst: $npm_typst"
    remove_package "npm uninstall -g typst" npm uninstall -g typst
fi

# --- Install/update ---
if command -v typst &>/dev/null; then
    typst_path=$(command -v typst)
    if [[ "$typst_path" == /opt/homebrew/* ]] || [[ "$typst_path" == /usr/local/* ]]; then
        log "Already installed via Homebrew -- upgrading..."
        upgrade_rc=0
        UPGRADE_OUTPUT=$(brew upgrade typst 2>&1) || upgrade_rc=$?
        if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'already installed\|up.to.date\|No available upgrade' >/dev/null; then
            log_ok "Typst already up to date"
            write_summary OK "typst" "$(typst --version)"
        else
            # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
            if [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'error\|fatal' >/dev/null; then
                # The installed typst still works: a warning, not an error (Standard 3).
                # error_reason logs the output as detail lines.
                write_warn "typst" "brew upgrade failed: $(error_reason "$UPGRADE_OUTPUT" "$upgrade_rc")"
                write_summary OK "typst" "$(typst --version)"
            else
                while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
                log_ok "$(typst --version)"
                write_summary OK "typst" "$(typst --version)"
            fi
        fi
    else
        write_warn "typst" "installed via a non-preferred method at $typst_path -- migrating to Homebrew"
        log "Migrating to Homebrew..."
        # brew's output streams to the console and deploy.log as it arrives and is
        # teed to a temporary file for the error reason (a failed install's output is
        # then in deploy.log twice: logging.md 8.2).
        INSTALL_OUTPUT=""
        INSTALL_RC=0
        # A failed mktemp is checked on the next line: the install then streams uncaptured
        INSTALL_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-typst.XXXXXX") || INSTALL_FILE=""
        if [ -n "$INSTALL_FILE" ]; then
            brew install typst 2>&1 | tee "$INSTALL_FILE" | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
            INSTALL_OUTPUT=$(cat "$INSTALL_FILE")
            rm -f "$INSTALL_FILE"
        else
            log_detail "mktemp failed -- the brew install output is not captured; the error reason falls back to its exit code"
            brew install typst 2>&1 | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
        fi
        if [ "$INSTALL_RC" -ne 0 ]; then
            write_error "typst" "brew install failed" "$(error_reason "$INSTALL_OUTPUT" "$INSTALL_RC")"
        fi
        if command -v typst &>/dev/null; then
            log_ok "Migrated to Homebrew: $(typst --version)"
            write_summary OK "typst" "$(typst --version)"
        elif [ "$INSTALL_RC" -ne 0 ]; then
            # One failure, one red line: the install error above is the cause
            log "typst not on PATH after the failed brew install"
        else
            write_error "typst" "installed but not on PATH" "command -v typst found nothing after brew install"
        fi
    fi
else
    log "Installing Typst via Homebrew..."
    # Streamed and teed, as above
    INSTALL_OUTPUT=""
    INSTALL_RC=0
    # A failed mktemp is checked on the next line: the install then streams uncaptured
    INSTALL_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-typst.XXXXXX") || INSTALL_FILE=""
    if [ -n "$INSTALL_FILE" ]; then
        brew install typst 2>&1 | tee "$INSTALL_FILE" | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
        INSTALL_OUTPUT=$(cat "$INSTALL_FILE")
        rm -f "$INSTALL_FILE"
    else
        log_detail "mktemp failed -- the brew install output is not captured; the error reason falls back to its exit code"
        brew install typst 2>&1 | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
    fi
    if [ "$INSTALL_RC" -ne 0 ]; then
        write_error "typst" "brew install failed" "$(error_reason "$INSTALL_OUTPUT" "$INSTALL_RC")"
    fi
    if command -v typst &>/dev/null; then
        log_ok "Typst installed ($(typst --version))"
        write_summary OK "typst" "$(typst --version)"
    elif [ "$INSTALL_RC" -ne 0 ]; then
        # One failure, one red line: the install error above is the cause
        log "typst not on PATH after the failed brew install"
    else
        write_error "typst" "installed but not on PATH" "command -v typst found nothing after brew install"
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
