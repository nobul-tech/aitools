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

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-gh-cli"

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
            UPGRADE_OUTPUT=$(brew upgrade gh 2>&1) || true
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
                log_ok "gh CLI already up to date"
                write_summary OK "gh cli" "$(gh --version | head -1)"
            else
                printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
                if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                    log_error "brew upgrade gh failed (see log above)"
                    write_summary ERROR "gh cli" "brew upgrade failed"
                else
                    log_ok "gh CLI $(gh --version | head -1)"
                    write_summary OK "gh cli" "$(gh --version | head -1)"
                fi
            fi
        else
            log "Installing gh CLI via Homebrew..."
            if ! brew install gh 2>&1 | while IFS= read -r line; do log "$line"; done; then
                log_error "brew install gh failed"
                write_summary ERROR "gh cli" "brew install failed"
            fi

            if command -v gh &>/dev/null; then
                log_ok "gh CLI installed ($(gh --version | head -1))"
                log_ok "Install path: $(command -v gh)"
                write_summary OK "gh cli" "$(gh --version | head -1)"
            else
                log_error "brew install completed but 'gh' not found in PATH"
                write_summary ERROR "gh cli" "installed but not on PATH"
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
                if ! { sudo apt-get update -qq && sudo apt-get install -y gh; } 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "apt-get install gh failed"
                    write_summary ERROR "gh cli" "apt-get install failed"
                fi
                if command -v gh &>/dev/null; then
                    log_ok "gh CLI updated/confirmed ($(gh --version | head -1))"
                    write_summary OK "gh cli" "$(gh --version | head -1)"
                else
                    log_error "apt-get completed but 'gh' not found in PATH"
                    write_summary ERROR "gh cli" "installed but not on PATH"
                fi
            else
                log "Installing gh CLI via apt + GitHub keyring..."
                if ! { (type -p wget >/dev/null || sudo apt-get install -y wget) \
                    && sudo mkdir -p -m 755 /etc/apt/keyrings \
                    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
                    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
                    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
                    && sudo apt-get update -qq && sudo apt-get install -y gh; } 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "apt keyring + install failed for gh CLI"
                    write_summary ERROR "gh cli" "apt install failed"
                fi

                if command -v gh &>/dev/null; then
                    log_ok "gh CLI installed ($(gh --version | head -1))"
                    write_summary OK "gh cli" "$(gh --version | head -1)"
                else
                    log_error "Failed to install gh CLI via apt"
                    write_summary ERROR "gh cli" "install failed"
                fi
            fi
        else
            log_error "No supported package manager found (apt). Install gh manually: https://cli.github.com"
            write_summary ERROR "gh cli" "no supported package manager"
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
