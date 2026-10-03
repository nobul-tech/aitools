#!/usr/bin/env bash
# setup-pandoc.sh — Installs/updates Pandoc
# Safe to re-run — detects existing install and upgrades or migrates as needed.
#
# macOS: Uses Homebrew (brew install pandoc).
#        If pandoc was previously installed via a non-preferred method, migrates to Homebrew.
# Linux: Uses apt install pandoc (Debian/Ubuntu). Skips with warning on other distros.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-pandoc"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

OS_NAME="$(uname -s)"

# Remove a non-preferred install: output goes to the log; a failed removal is a
# warning (non-blocking -- the Homebrew install below proceeds).
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

# --- Install/update ---
case "$OS_NAME" in
    Darwin)
        # macOS: Homebrew is the preferred method
        if ! command -v brew &>/dev/null; then
            log_error "Homebrew not found. Install pandoc manually:"
            log_error "  1. Install Homebrew: https://brew.sh"
            log_error "  2. brew install pandoc"
            write_summary ERROR "pandoc" "Homebrew not found"
            exit 1
        fi

        if command -v pandoc &>/dev/null; then
            pandoc_path="$(command -v pandoc)"
            pandoc_version="$(pandoc --version | head -1)"
            log "Pandoc $pandoc_version found at $pandoc_path"

            # Check if installed via Homebrew (path contains /opt/homebrew/ or /usr/local/)
            if [[ "$pandoc_path" == /opt/homebrew/* ]] || [[ "$pandoc_path" == /usr/local/* ]]; then
                log "Already installed via Homebrew — upgrading..."
                upgrade_rc=0
                UPGRADE_OUTPUT=$(brew upgrade pandoc 2>&1) || upgrade_rc=$?
                if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
                    log_ok "Pandoc already up to date"
                    write_summary OK "pandoc" "$(pandoc --version | head -1)"
                else
                    while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
                    # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
                    if [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                        log_error "brew upgrade pandoc failed (exit $upgrade_rc) -- see $(display_path "$LOG_FILE")"
                        write_summary ERROR "pandoc" "brew upgrade failed (exit $upgrade_rc)"
                    else
                        log_ok "Pandoc $(pandoc --version | head -1)"
                        write_summary OK "pandoc" "$(pandoc --version | head -1)"
                    fi
                fi
            else
                # Not Homebrew — migrate
                log_warn "Pandoc installed via non-preferred method at $pandoc_path"
                log "Migrating to Homebrew..."

                # Detect and clean up known non-preferred installs (only those present;
                # the probes' output goes to the log so a failed probe is visible).
                if command -v conda &>/dev/null; then
                    conda_rc=0
                    conda_list=$(conda list pandoc 2>&1) || conda_rc=$?
                    if [ "$conda_rc" -ne 0 ]; then
                        log_detail "conda-list-pandoc: $conda_list"
                        log_warn "conda list pandoc failed (exit $conda_rc) -- skipping conda cleanup"
                    elif printf '%s\n' "$conda_list" | grep -q '^pandoc '; then
                        log_warn "Removing conda pandoc..."
                        remove_package "conda remove -y pandoc" conda remove -y pandoc
                    fi
                fi
                if command -v port &>/dev/null; then
                    port_rc=0
                    port_list=$(port installed pandoc 2>&1) || port_rc=$?
                    if [ "$port_rc" -ne 0 ]; then
                        log_detail "port-installed-pandoc: $port_list"
                        log_warn "port installed pandoc failed (exit $port_rc) -- skipping MacPorts cleanup"
                    elif printf '%s\n' "$port_list" | grep -q '^ *pandoc '; then
                        log_warn "Removing MacPorts pandoc..."
                        remove_package "sudo port uninstall pandoc" sudo port uninstall pandoc
                    fi
                fi
                if [ -f "$HOME/.cabal/bin/pandoc" ]; then
                    log_warn "Removing Cabal pandoc..."
                    remove_package "rm ~/.cabal/bin/pandoc" rm -f "$HOME/.cabal/bin/pandoc"
                fi

                if ! brew install pandoc 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "brew install pandoc failed"
                    write_summary ERROR "pandoc" "brew install failed"
                fi

                if command -v pandoc &>/dev/null; then
                    log_ok "Migrated to Homebrew: Pandoc $(pandoc --version | head -1)"
                    log_ok "Install path: $(command -v pandoc)"
                    write_summary OK "pandoc" "$(pandoc --version | head -1)"
                else
                    log_error "Homebrew install succeeded but 'pandoc' not found in PATH"
                    write_summary ERROR "pandoc" "installed but not on PATH"
                fi
            fi
        else
            # Fresh install
            log "Installing Pandoc via Homebrew..."
            if ! brew install pandoc 2>&1 | while IFS= read -r line; do log "$line"; done; then
                log_error "brew install pandoc failed"
                write_summary ERROR "pandoc" "brew install failed"
            fi

            if command -v pandoc &>/dev/null; then
                log_ok "Pandoc installed ($(pandoc --version | head -1))"
                log_ok "Install path: $(command -v pandoc)"
                write_summary OK "pandoc" "$(pandoc --version | head -1)"
            else
                log_error "brew install completed but 'pandoc' not found in PATH"
                write_summary ERROR "pandoc" "installed but not on PATH"
            fi
        fi
        ;;

    *)
        # Linux: apt is the preferred method
        if command -v apt-get &>/dev/null; then
            if command -v pandoc &>/dev/null; then
                log_ok "Pandoc already installed ($(pandoc --version | head -1))"
                write_summary OK "pandoc" "$(pandoc --version | head -1)"
            else
                log "Installing Pandoc via apt..."
                if ! { sudo apt-get update -qq && sudo apt-get install -y pandoc; } 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "apt-get install pandoc failed"
                    write_summary ERROR "pandoc" "apt-get install failed"
                fi
                if command -v pandoc &>/dev/null; then
                    log_ok "Pandoc installed ($(pandoc --version | head -1))"
                    write_summary OK "pandoc" "$(pandoc --version | head -1)"
                else
                    log_error "apt install completed but 'pandoc' not found in PATH"
                    write_summary ERROR "pandoc" "installed but not on PATH"
                fi
            fi
        else
            log_error "No supported package manager found (apt). Install pandoc manually: https://pandoc.org/installing.html"
            write_summary ERROR "pandoc" "no supported package manager"
        fi
        ;;
esac

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
