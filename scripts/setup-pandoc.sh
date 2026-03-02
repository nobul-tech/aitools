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

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-pandoc"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }
write_summary() {
    local cat="$1" msg="$2"
    [ -n "${AITOOLS_SUMMARY_FILE:-}" ] && printf '%s|%s\n' "$cat" "$msg" >> "$AITOOLS_SUMMARY_FILE"
}

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
                brew upgrade pandoc 2>/dev/null || log_ok "Pandoc already up to date"
                log_ok "Pandoc $(pandoc --version | head -1)"
                write_summary OK "pandoc    $(pandoc --version | head -1)"
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

                brew install pandoc

                if command -v pandoc &>/dev/null; then
                    log_ok "Migrated to Homebrew: Pandoc $(pandoc --version | head -1)"
                    log_ok "Install path: $(command -v pandoc)"
                    write_summary OK "pandoc    $(pandoc --version | head -1)"
                else
                    log_error "Homebrew install succeeded but 'pandoc' not found in PATH"
                fi
            fi
        else
            # Fresh install
            log "Installing Pandoc via Homebrew..."
            brew install pandoc

            if command -v pandoc &>/dev/null; then
                log_ok "Pandoc installed ($(pandoc --version | head -1))"
                log_ok "Install path: $(command -v pandoc)"
                write_summary OK "pandoc    $(pandoc --version | head -1)"
            else
                log_error "brew install completed but 'pandoc' not found in PATH"
            fi
        fi
        ;;

    *)
        # Linux: apt is the preferred method
        if command -v apt-get &>/dev/null; then
            if command -v pandoc &>/dev/null; then
                log_ok "Pandoc already installed ($(pandoc --version | head -1))"
                write_summary OK "pandoc    $(pandoc --version | head -1)"
            else
                log "Installing Pandoc via apt..."
                sudo apt-get update -qq && sudo apt-get install -y pandoc
                if command -v pandoc &>/dev/null; then
                    log_ok "Pandoc installed ($(pandoc --version | head -1))"
                    write_summary OK "pandoc    $(pandoc --version | head -1)"
                else
                    log_error "apt install completed but 'pandoc' not found in PATH"
                fi
            fi
        else
            log_warn "No supported package manager found (apt). Install pandoc manually: https://pandoc.org/installing.html"
        fi
        ;;
esac

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $LOG_FILE"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
