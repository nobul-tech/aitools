#!/usr/bin/env bash
# setup-vercelcli.sh — Installs/updates Vercel CLI
# Safe to re-run — detects existing install and upgrades or migrates as needed.
#
# macOS: Uses Homebrew (brew install vercel-cli) for Claude Code PATH compatibility.
#        If vercel was previously installed via npm, migrates to Homebrew automatically.
# Linux: Uses npm install -g vercel (no Homebrew available).
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-vercelcli"

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
                UPGRADE_OUTPUT=$(brew upgrade vercel-cli 2>&1) || true
                if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
                    log_ok "Vercel CLI already up to date"
                    write_summary OK "vercel cli" "$(vercel --version 2>/dev/null | head -1)"
                else
                    printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
                    if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                        log_error "brew upgrade vercel-cli failed (see log above)"
                        write_summary ERROR "vercel cli" "brew upgrade failed"
                    else
                        log_ok "Vercel CLI $(vercel --version 2>/dev/null | head -1)"
                        write_summary OK "vercel cli" "$(vercel --version 2>/dev/null | head -1)"
                    fi
                fi
            else
                # Not Homebrew — migrate from npm to Homebrew
                log_warn "Vercel CLI installed via npm at $vercel_path"
                log "Migrating to Homebrew for Claude Code PATH compatibility..."

                # Cleanup: npm uninstall may fail if partially removed; non-blocking
                npm uninstall -g vercel 2>/dev/null || true
                if ! brew install vercel-cli 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "brew install vercel-cli failed"
                    write_summary ERROR "vercel cli" "brew install failed"
                fi

                if command -v vercel &>/dev/null; then
                    log_ok "Migrated to Homebrew: Vercel CLI $(vercel --version 2>/dev/null | head -1)"
                    log_ok "Install path: $(command -v vercel)"
                    write_summary OK "vercel cli" "$(vercel --version 2>/dev/null | head -1)"
                else
                    log_error "Homebrew install succeeded but 'vercel' not found in PATH"
                    write_summary ERROR "vercel cli" "installed but not on PATH"
                fi
            fi
        else
            # Fresh install
            log "Installing Vercel CLI via Homebrew..."
            if ! brew install vercel-cli 2>&1 | while IFS= read -r line; do log "$line"; done; then
                log_error "brew install vercel-cli failed"
                write_summary ERROR "vercel cli" "brew install failed"
            fi

            if command -v vercel &>/dev/null; then
                log_ok "Vercel CLI installed ($(vercel --version 2>/dev/null | head -1))"
                log_ok "Install path: $(command -v vercel)"
                write_summary OK "vercel cli" "$(vercel --version 2>/dev/null | head -1)"
            else
                log_error "brew install completed but 'vercel' not found in PATH"
                write_summary ERROR "vercel cli" "installed but not on PATH"
            fi
        fi
        ;;

    *)
        # Linux: npm is the only option
        if ! command -v npm &>/dev/null; then
            log_error "npm not found — install Node.js first"
            write_summary ERROR "vercel cli" "npm not found (install Node.js)"
            exit 1
        fi

        if command -v vercel &>/dev/null; then
            log_ok "Vercel CLI already installed ($(vercel --version 2>/dev/null | head -1))"
            write_summary OK "vercel cli" "$(vercel --version 2>/dev/null | head -1)"
        else
            log "Installing Vercel CLI via npm..."
            NPM_OUTPUT=$(npm install -g vercel 2>&1) || true
            printf '%s\n' "$NPM_OUTPUT" | while IFS= read -r line; do log "$line"; done
            if printf '%s\n' "$NPM_OUTPUT" | grep -qi 'ERR!\|error'; then
                log_error "npm install vercel reported errors (see log above)"
                write_summary ERROR "vercel cli" "npm install failed"
            fi

            if command -v vercel &>/dev/null; then
                log_ok "Vercel CLI installed ($(vercel --version 2>/dev/null | head -1))"
                write_summary OK "vercel cli" "$(vercel --version 2>/dev/null | head -1)"
            else
                log_error "Vercel CLI install failed"
                write_summary ERROR "vercel cli" "install failed"
            fi
        fi
        ;;
esac

# Only suggest auth if vercel is installed but not authenticated
if command -v vercel >/dev/null 2>&1; then
    if ! vercel whoami >/dev/null 2>&1; then
        log_warn "Authentication required: run 'vercel login' to authenticate"
        write_summary ACTION "" "vercel login -- authenticate vercel CLI"
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
