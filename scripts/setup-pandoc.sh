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

# --- Install/update ---
case "$OS_NAME" in
    Darwin)
        # macOS: Homebrew is the preferred method
        if ! command -v brew &>/dev/null; then
            log_error "Homebrew not found. Install pandoc manually:"
            log_error "  1. Install Homebrew: https://brew.sh"
            log_error "  2. brew install pandoc"
            exit 1
        fi

        if command -v pandoc &>/dev/null; then
            pandoc_path="$(command -v pandoc)"
            pandoc_version="$(pandoc --version | head -1)"
            log "Pandoc $pandoc_version found at $pandoc_path"

            # Check if installed via Homebrew (path contains /opt/homebrew/ or /usr/local/)
            if [[ "$pandoc_path" == /opt/homebrew/* ]] || [[ "$pandoc_path" == /usr/local/* ]]; then
                log "Already installed via Homebrew — upgrading..."
                UPGRADE_OUTPUT=$(brew upgrade pandoc 2>&1) || true
                if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
                    log_ok "Pandoc already up to date"
                    write_summary OK "pandoc" "$(pandoc --version | head -1)"
                else
                    printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
                    if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                        log_error "brew upgrade pandoc failed (see log above)"
                        write_summary ERROR "pandoc" "brew upgrade failed"
                    else
                        log_ok "Pandoc $(pandoc --version | head -1)"
                        write_summary OK "pandoc" "$(pandoc --version | head -1)"
                    fi
                fi
            else
                # Not Homebrew — migrate
                log_warn "Pandoc installed via non-preferred method at $pandoc_path"
                log "Migrating to Homebrew..."

                # Detect and clean up known non-preferred installs
                if command -v conda &>/dev/null && conda list pandoc 2>/dev/null | grep -q pandoc; then
                    log_warn "Removing conda pandoc..."
                    # Cleanup: conda remove may fail if partially removed; non-blocking
                    conda remove -y pandoc 2>/dev/null || true
                fi
                if command -v port &>/dev/null && port installed pandoc 2>/dev/null | grep -q pandoc; then
                    log_warn "Removing MacPorts pandoc..."
                    # Cleanup: port uninstall may fail if partially removed; non-blocking
                    sudo port uninstall pandoc 2>/dev/null || true
                fi
                if [ -f "$HOME/.cabal/bin/pandoc" ]; then
                    log_warn "Removing Cabal pandoc..."
                    # Cleanup: cabal binary may already be gone; non-blocking
                    rm -f "$HOME/.cabal/bin/pandoc" 2>/dev/null || true
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
