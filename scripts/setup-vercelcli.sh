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

# Log captured command output to the log file as detail lines (blank lines skipped).
write_output_detail() {  # label, output
    local line
    while IFS= read -r line; do
        if [ -n "${line// /}" ]; then log_detail "$1: $line"; fi
    done <<< "$2"
}

# Set VERCEL_VERSION from `vercel --version` (first line with a version number). A failed
# probe logs its output and leaves "version unknown"; install results are decided by
# the brew/npm exit code, not by this probe.
read_vercel_version() {
    local out rc=0 line
    out=$(vercel --version 2>&1) || rc=$?
    VERCEL_VERSION="version unknown"
    if [ "$rc" -eq 0 ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then VERCEL_VERSION="$line"; return 0; fi
        done <<< "$out"
    fi
    write_output_detail "vercel-version (exit $rc)" "$out"
}

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
            write_summary ERROR "vercel cli" "Homebrew not found"
            exit 1
        fi

        if command -v vercel &>/dev/null; then
            vercel_path="$(command -v vercel)"
            read_vercel_version
            log "Vercel CLI $VERCEL_VERSION found at $vercel_path"

            # Check if installed via Homebrew (path contains /opt/homebrew/ or /usr/local/)
            if [[ "$vercel_path" == /opt/homebrew/* ]] || [[ "$vercel_path" == /usr/local/* ]]; then
                log "Already installed via Homebrew — upgrading..."
                upgrade_rc=0
                UPGRADE_OUTPUT=$(brew upgrade vercel-cli 2>&1) || upgrade_rc=$?
                if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
                    log_ok "Vercel CLI already up to date"
                    write_summary OK "vercel cli" "$VERCEL_VERSION"
                else
                    while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
                    # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
                    if [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                        log_error "brew upgrade vercel-cli failed (exit $upgrade_rc) -- see $(display_path "$LOG_FILE")"
                        write_summary ERROR "vercel cli" "brew upgrade failed (exit $upgrade_rc)"
                    else
                        read_vercel_version
                        log_ok "Vercel CLI $VERCEL_VERSION"
                        write_summary OK "vercel cli" "$VERCEL_VERSION"
                    fi
                fi
            else
                # Not Homebrew — migrate from npm to Homebrew
                log_warn "Vercel CLI installed via npm at $vercel_path"
                log "Migrating to Homebrew for Claude Code PATH compatibility..."

                # Non-blocking: brew install below proceeds; the npm copy may shadow it on PATH.
                uninstall_rc=0
                uninstall_out=$(npm uninstall -g vercel 2>&1) || uninstall_rc=$?
                write_output_detail "npm-uninstall-vercel" "$uninstall_out"
                if [ "$uninstall_rc" -ne 0 ]; then
                    log_warn "npm uninstall -g vercel failed (exit $uninstall_rc) -- see $(display_path "$LOG_FILE")"
                fi
                hash -r
                if ! brew install vercel-cli 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "brew install vercel-cli failed"
                    write_summary ERROR "vercel cli" "brew install failed"
                elif command -v vercel &>/dev/null; then
                    read_vercel_version
                    log_ok "Migrated to Homebrew: Vercel CLI $VERCEL_VERSION"
                    log_ok "Install path: $(command -v vercel)"
                    write_summary OK "vercel cli" "$VERCEL_VERSION"
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
            elif command -v vercel &>/dev/null; then
                read_vercel_version
                log_ok "Vercel CLI installed ($VERCEL_VERSION)"
                log_ok "Install path: $(command -v vercel)"
                write_summary OK "vercel cli" "$VERCEL_VERSION"
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
            read_vercel_version
            log_ok "Vercel CLI already installed ($VERCEL_VERSION)"
            write_summary OK "vercel cli" "$VERCEL_VERSION"
        else
            log "Installing Vercel CLI via npm..."
            # Exit code decides (C-F2); the full output goes to the log as detail.
            npm_rc=0
            NPM_OUTPUT=$(npm install -g vercel 2>&1) || npm_rc=$?
            write_output_detail "npm-install-vercel" "$NPM_OUTPUT"
            hash -r
            if [ "$npm_rc" -ne 0 ]; then
                log_error "npm install -g vercel failed (exit $npm_rc) -- see $(display_path "$LOG_FILE")"
                write_summary ERROR "vercel cli" "npm install failed (exit $npm_rc)"
            elif command -v vercel &>/dev/null; then
                read_vercel_version
                log_ok "Vercel CLI installed ($VERCEL_VERSION)"
                write_summary OK "vercel cli" "$VERCEL_VERSION"
            else
                log_error "npm install completed but 'vercel' not found in PATH"
                write_summary ERROR "vercel cli" "installed but not on PATH"
            fi
        fi
        ;;
esac

# --- Auth status check (script-standards-detail.md: command exit code pattern) ---
if command -v vercel >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    whoami_rc=0
    whoami_out=$(vercel whoami 2>&1) || whoami_rc=$?
    if [ "$whoami_rc" -ne 0 ]; then
        write_output_detail "vercel-whoami (exit $whoami_rc)" "$whoami_out"
        log_warn "Authentication required: run 'vercel login' to authenticate"
        write_summary WARN "vercel cli" "not authenticated"
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
