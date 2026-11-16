#!/usr/bin/env bash
# setup-pandoc.sh — Installs/updates Pandoc
# Safe to re-run — detects existing install and upgrades or migrates as needed.
#
# macOS: Uses Homebrew (brew install pandoc).
#        If pandoc was previously installed via a non-preferred method, migrates to Homebrew.
# Linux: Uses apt install pandoc (Debian/Ubuntu). Skips with warning on other distros.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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

# Remove a non-preferred install: output goes to the log; a failed removal is a
# warning (non-blocking -- the Homebrew install below proceeds) whose reason is
# taken from the output (error_reason logs that output as detail lines).
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
        write_warn "pandoc" "$label failed: $(error_reason "$out" "$rc")"
    fi
}

# --- Install/update ---
case "$AITOOLS_PLATFORM" in
    macos)
        # macOS: Homebrew is the preferred method
        if ! command -v brew &>/dev/null; then
            write_error "pandoc" "Homebrew not found" "brew is not on PATH"
            log "Install pandoc manually:"
            log "  1. Install Homebrew: https://brew.sh"
            log "  2. brew install pandoc"
            exit 1
        fi

        if command -v pandoc &>/dev/null; then
            pandoc_path="$(command -v pandoc)"
            pandoc_version="$(pandoc --version | sed -n '1p')"
            log "Pandoc $pandoc_version found at $pandoc_path"

            # Check if installed via Homebrew (path contains /opt/homebrew/ or /usr/local/)
            if [[ "$pandoc_path" == /opt/homebrew/* ]] || [[ "$pandoc_path" == /usr/local/* ]]; then
                log "Already installed via Homebrew — upgrading..."
                upgrade_rc=0
                UPGRADE_OUTPUT=$(brew upgrade pandoc 2>&1) || upgrade_rc=$?
                if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'already installed\|up.to.date\|No available upgrade' >/dev/null; then
                    log_ok "Pandoc already up to date"
                    write_summary OK "pandoc" "$(pandoc --version | sed -n '1p')"
                elif [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'error\|fatal' >/dev/null; then
                    # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
                    # The installed pandoc still works: a warning plus its OK status
                    # (script-standards-detail Standard 3); error_reason logs the output
                    write_warn "pandoc" "brew upgrade failed: $(error_reason "$UPGRADE_OUTPUT" "$upgrade_rc")"
                    write_summary OK "pandoc" "$(pandoc --version | sed -n '1p')"
                else
                    while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
                    log_ok "Pandoc $(pandoc --version | sed -n '1p')"
                    write_summary OK "pandoc" "$(pandoc --version | sed -n '1p')"
                fi
            else
                # Not Homebrew — migrate
                write_warn "pandoc" "installed via a non-preferred method at $pandoc_path -- migrating to Homebrew"
                log "Migrating to Homebrew..."

                # Detect and clean up known non-preferred installs (only those present;
                # a failed probe is a warning whose reason comes from its output).
                if command -v conda &>/dev/null; then
                    conda_rc=0
                    conda_list=$(conda list pandoc 2>&1) || conda_rc=$?
                    if [ "$conda_rc" -ne 0 ]; then
                        write_warn "pandoc" "conda list pandoc failed, conda cleanup skipped: $(error_reason "$conda_list" "$conda_rc")"
                    elif printf '%s\n' "$conda_list" | grep '^pandoc ' >/dev/null; then
                        log "Removing conda pandoc..."
                        remove_package "conda remove -y pandoc" conda remove -y pandoc
                    fi
                fi
                if command -v port &>/dev/null; then
                    port_rc=0
                    port_list=$(port installed pandoc 2>&1) || port_rc=$?
                    if [ "$port_rc" -ne 0 ]; then
                        write_warn "pandoc" "port installed pandoc failed, MacPorts cleanup skipped: $(error_reason "$port_list" "$port_rc")"
                    elif printf '%s\n' "$port_list" | grep '^ *pandoc ' >/dev/null; then
                        log "Removing MacPorts pandoc..."
                        remove_package "sudo port uninstall pandoc" sudo port uninstall pandoc
                    fi
                fi
                if [ -f "$HOME/.cabal/bin/pandoc" ]; then
                    log "Removing Cabal pandoc..."
                    remove_package "rm ~/.cabal/bin/pandoc" rm -f "$HOME/.cabal/bin/pandoc"
                fi

                # Stream the install to the console and tee it to a file, so a
                # failure has output to take its reason from (logging.md 8.2: on a
                # failure the output is in deploy.log twice, streamed and as detail).
                # Under pipefail the pipeline's status is brew's: tee and the loop exit 0.
                CMD_OUT=""
                CMD_RC=0
                CMD_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-pandoc.XXXXXX") || CMD_FILE=""
                if [ -n "$CMD_FILE" ]; then
                    brew install pandoc 2>&1 | tee "$CMD_FILE" | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
                    CMD_OUT=$(cat "$CMD_FILE")
                    rm -f "$CMD_FILE"
                else
                    # mktemp failed: stream as before; the reason falls back to "no output (exit N)"
                    brew install pandoc 2>&1 | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
                fi
                if [ "$CMD_RC" -ne 0 ]; then
                    write_error "pandoc" "brew install failed" "$(error_reason "$CMD_OUT" "$CMD_RC")"
                fi

                if command -v pandoc &>/dev/null; then
                    log_ok "Migrated to Homebrew: Pandoc $(pandoc --version | sed -n '1p')"
                    log_ok "Install path: $(command -v pandoc)"
                    write_summary OK "pandoc" "$(pandoc --version | sed -n '1p')"
                elif [ "$CMD_RC" -ne 0 ]; then
                    # One failed install, one red line: the brew error above is the cause
                    log "pandoc not on PATH after the failed install"
                else
                    write_error "pandoc" "installed but not on PATH" "command -v pandoc found nothing after brew install"
                fi
            fi
        else
            # Fresh install
            log "Installing Pandoc via Homebrew..."
            # Streamed and teed, as in the migration above
            CMD_OUT=""
            CMD_RC=0
            CMD_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-pandoc.XXXXXX") || CMD_FILE=""
            if [ -n "$CMD_FILE" ]; then
                brew install pandoc 2>&1 | tee "$CMD_FILE" | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
                CMD_OUT=$(cat "$CMD_FILE")
                rm -f "$CMD_FILE"
            else
                # mktemp failed: stream as before; the reason falls back to "no output (exit N)"
                brew install pandoc 2>&1 | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
            fi
            if [ "$CMD_RC" -ne 0 ]; then
                write_error "pandoc" "brew install failed" "$(error_reason "$CMD_OUT" "$CMD_RC")"
            fi

            if command -v pandoc &>/dev/null; then
                log_ok "Pandoc installed ($(pandoc --version | sed -n '1p'))"
                log_ok "Install path: $(command -v pandoc)"
                write_summary OK "pandoc" "$(pandoc --version | sed -n '1p')"
            elif [ "$CMD_RC" -ne 0 ]; then
                # One failed install, one red line: the brew error above is the cause
                log "pandoc not on PATH after the failed install"
            else
                write_error "pandoc" "installed but not on PATH" "command -v pandoc found nothing after brew install"
            fi
        fi
        ;;

    *)
        # Linux: apt is the preferred method
        if command -v apt-get &>/dev/null; then
            if command -v pandoc &>/dev/null; then
                log_ok "Pandoc already installed ($(pandoc --version | sed -n '1p'))"
                write_summary OK "pandoc" "$(pandoc --version | sed -n '1p')"
            else
                log "Installing Pandoc via apt..."
                # Streamed and teed, as in the macOS branch; the brace group's
                # status is the first failing apt-get's
                CMD_OUT=""
                CMD_RC=0
                CMD_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-pandoc.XXXXXX") || CMD_FILE=""
                if [ -n "$CMD_FILE" ]; then
                    { sudo apt-get update -qq && sudo apt-get install -y pandoc; } 2>&1 | tee "$CMD_FILE" | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
                    CMD_OUT=$(cat "$CMD_FILE")
                    rm -f "$CMD_FILE"
                else
                    # mktemp failed: stream as before; the reason falls back to "no output (exit N)"
                    { sudo apt-get update -qq && sudo apt-get install -y pandoc; } 2>&1 | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
                fi
                if [ "$CMD_RC" -ne 0 ]; then
                    write_error "pandoc" "apt-get install failed" "$(error_reason "$CMD_OUT" "$CMD_RC")"
                fi
                if command -v pandoc &>/dev/null; then
                    log_ok "Pandoc installed ($(pandoc --version | sed -n '1p'))"
                    write_summary OK "pandoc" "$(pandoc --version | sed -n '1p')"
                elif [ "$CMD_RC" -ne 0 ]; then
                    # One failed install, one red line: the apt-get error above is the cause
                    log "pandoc not on PATH after the failed install"
                else
                    write_error "pandoc" "installed but not on PATH" "command -v pandoc found nothing after apt-get install"
                fi
            fi
        else
            write_error "pandoc" "no supported package manager" "apt-get not found -- install pandoc manually: https://pandoc.org/installing.html"
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
