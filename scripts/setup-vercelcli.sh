#!/usr/bin/env bash
# setup-vercelcli.sh — Installs/updates Vercel CLI
# Safe to re-run — detects existing install and upgrades or migrates as needed.
#
# macOS: Uses Homebrew (brew install vercel-cli) for Claude Code PATH compatibility.
#        If vercel was previously installed via npm, migrates to Homebrew automatically.
# Linux: Uses npm install -g vercel (no Homebrew available).
#
# See reference/tool-install-sources.md for install source details.

set -euo pipefail

# --- Logging ---
LOG_DIR="$HOME/Library/Logs/aitools"
[ "$(uname -s)" != "Darwin" ] && LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
LOG_FILE="$LOG_DIR/deploy.log"
SCRIPT_NAME="setup-vercelcli"
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
        # macOS: Homebrew is the preferred method (installs to /opt/homebrew/bin/ or
        # /usr/local/bin/ which Claude Code's Bash tool reliably finds).
        # npm global installs go to ~/.npm-global/bin/ which is often missing from
        # Claude Code's PATH. See: https://github.com/anthropics/claude-code/issues/5202

        if ! command -v brew &>/dev/null; then
            log_error "Homebrew not found. Install Vercel CLI manually:"
            log_error "  1. Install Homebrew: https://brew.sh"
            log_error "  2. brew install vercel-cli"
            exit 1
        fi

        if command -v vercel &>/dev/null; then
            vercel_path="$(command -v vercel)"
            vercel_version="$(vercel --version 2>/dev/null | head -1)"
            log "Vercel CLI $vercel_version found at $vercel_path"

            # Check if installed via Homebrew (path contains /opt/homebrew/ or /usr/local/)
            if [[ "$vercel_path" == /opt/homebrew/* ]] || [[ "$vercel_path" == /usr/local/* ]]; then
                log "Already installed via Homebrew — upgrading..."
                brew upgrade vercel-cli 2>/dev/null || log_ok "Vercel CLI already up to date"
                log_ok "Vercel CLI $(vercel --version 2>/dev/null | head -1)"
            else
                # Not Homebrew — migrate from npm to Homebrew
                log_warn "Vercel CLI installed via npm at $vercel_path"
                log "Migrating to Homebrew for Claude Code PATH compatibility..."

                # Cleanup: npm uninstall may fail if partially removed; non-blocking
                npm uninstall -g vercel 2>/dev/null || true
                brew install vercel-cli

                if command -v vercel &>/dev/null; then
                    log_ok "Migrated to Homebrew: Vercel CLI $(vercel --version 2>/dev/null | head -1)"
                    log_ok "Install path: $(command -v vercel)"
                else
                    log_error "Homebrew install succeeded but 'vercel' not found in PATH"
                fi
            fi
        else
            # Fresh install
            log "Installing Vercel CLI via Homebrew..."
            brew install vercel-cli

            if command -v vercel &>/dev/null; then
                log_ok "Vercel CLI installed ($(vercel --version 2>/dev/null | head -1))"
                log_ok "Install path: $(command -v vercel)"
            else
                log_error "brew install completed but 'vercel' not found in PATH"
            fi
        fi
        ;;

    *)
        # Linux: npm is the only option
        if ! command -v npm &>/dev/null; then
            log_error "npm not found — install Node.js first"
            exit 1
        fi

        if command -v vercel &>/dev/null; then
            log_ok "Vercel CLI already installed ($(vercel --version 2>/dev/null | head -1))"
        else
            log "Installing Vercel CLI via npm..."
            npm install -g vercel 2>/dev/null

            if command -v vercel &>/dev/null; then
                log_ok "Vercel CLI installed ($(vercel --version 2>/dev/null | head -1))"
            else
                log_error "Vercel CLI install failed"
            fi
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
