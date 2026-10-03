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
# Only packages that are actually installed are removed; a failed removal is a
# warning (non-blocking -- the Homebrew install below proceeds), with the output logged.
remove_package() {  # label, command...
    local label="$1"; shift
    local out rc=0 line
    out=$("$@" 2>&1) || rc=$?
    while IFS= read -r line; do
        if [ -n "${line// /}" ]; then log_detail "$label: $line"; fi
    done <<< "$out"
    if [ "$rc" -eq 0 ]; then
        log "Removed non-preferred install ($label)"
    else
        log_warn "$label failed (exit $rc) -- see $(display_path "$LOG_FILE")"
    fi
}
# Cargo typst-cli conflicts with Homebrew typst (different binary paths)
if command -v cargo &>/dev/null; then
    cargo_list_rc=0
    cargo_list=$(cargo install --list 2>&1) || cargo_list_rc=$?
    if [ "$cargo_list_rc" -ne 0 ]; then
        log_detail "cargo-install-list: $cargo_list"
        log_warn "cargo install --list failed (exit $cargo_list_rc) -- skipping cargo typst-cli cleanup"
    elif printf '%s\n' "$cargo_list" | grep -q '^typst-cli '; then
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
        if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
            log_ok "Typst already up to date"
            write_summary OK "typst" "$(typst --version)"
        else
            while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
            # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
            if [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                log_error "brew upgrade typst failed (exit $upgrade_rc) -- see $(display_path "$LOG_FILE")"
                write_summary ERROR "typst" "brew upgrade failed (exit $upgrade_rc)"
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
