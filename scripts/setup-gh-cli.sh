#!/usr/bin/env bash
# setup-gh-cli.sh — Installs/updates GitHub CLI (gh)
# Safe to re-run — detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (brew install gh).
# Linux: Uses apt + GitHub CLI keyring (added on first install only).
#        Falls back with warning on non-apt systems.
#
# Auth (gh auth login) is interactive — handled by aitools-install Step 2, not here.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-gh-cli"
mkdir -p "$LOG_DIR"

display_path() {
    if command -v cygpath &>/dev/null; then cygpath -w "$1"; else printf '%s' "$1"; fi
}
ERRORS=0
log()       { printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" | tee -a "$LOG_FILE"; }
log_ok()    { log "OK: $1"; }
log_error() { log "ERROR: $1"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "WARN: $1"; }

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
            log_error "Homebrew not found. Install gh manually:"
            log_error "  1. Install Homebrew: https://brew.sh"
            log_error "  2. brew install gh"
            exit 1
        fi

        if command -v gh &>/dev/null; then
            log "gh CLI already installed ($(gh --version | head -1))"
            log "Checking for updates via Homebrew..."
            brew upgrade gh 2>/dev/null || log_ok "gh CLI already up to date"
            log_ok "gh CLI $(gh --version | head -1)"
        else
            log "Installing gh CLI via Homebrew..."
            brew install gh

            if command -v gh &>/dev/null; then
                log_ok "gh CLI installed ($(gh --version | head -1))"
                log_ok "Install path: $(command -v gh)"
            else
                log_error "brew install completed but 'gh' not found in PATH"
            fi
        fi
        ;;

    *)
        # Linux: apt is the preferred method
        if command -v apt-get &>/dev/null; then
            if command -v gh &>/dev/null; then
                log "gh CLI already installed ($(gh --version | head -1))"
                log "Updating via apt..."
                # apt handles idempotency; keyring was added on first install
                sudo apt-get update -qq && sudo apt-get install -y gh
                if command -v gh &>/dev/null; then
                    log_ok "gh CLI updated/confirmed ($(gh --version | head -1))"
                else
                    log_error "apt-get completed but 'gh' not found in PATH"
                fi
            else
                log "Installing gh CLI via apt + GitHub keyring..."
                (type -p wget >/dev/null || sudo apt-get install -y wget) \
                    && sudo mkdir -p -m 755 /etc/apt/keyrings \
                    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
                    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
                    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
                    && sudo apt-get update -qq && sudo apt-get install -y gh

                if command -v gh &>/dev/null; then
                    log_ok "gh CLI installed ($(gh --version | head -1))"
                else
                    log_error "Failed to install gh CLI via apt"
                fi
            fi
        else
            log_warn "No supported package manager found (apt). Install gh manually: https://cli.github.com"
        fi
        ;;
esac

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s). See log: $(display_path "$LOG_FILE")"
    exit 1
else
    log "COMPLETED successfully"
    exit 0
fi
