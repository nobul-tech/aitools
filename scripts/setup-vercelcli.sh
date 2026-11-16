#!/usr/bin/env bash
# setup-vercelcli.sh — Installs/updates Vercel CLI
# Safe to re-run — detects existing install and upgrades or migrates as needed.
#
# macOS: Uses Homebrew (brew install vercel-cli) for Claude Code PATH compatibility.
#        If vercel was previously installed via npm, migrates to Homebrew automatically.
# Linux: Uses npm install -g vercel (no Homebrew available).
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
# The platform comes from the library (AITOOLS_PLATFORM: macos, linux), not a
# second uname read (.claude/rules/cross-platform.md "Environment branches")
case "$AITOOLS_PLATFORM" in
    macos)
        # macOS: Homebrew is the preferred method (installs to /opt/homebrew/bin/ or
        # /usr/local/bin/ which Claude Code's Bash tool reliably finds).
        # npm global installs go to ~/.npm-global/bin/ which is often missing from
        # Claude Code's PATH. See: https://github.com/anthropics/claude-code/issues/5202

        if ! command -v brew &>/dev/null; then
            write_error "vercel cli" "Homebrew not found" "brew is not on PATH"
            log "Install Vercel CLI manually:"
            log "  1. Install Homebrew: https://brew.sh"
            log "  2. brew install vercel-cli"
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
                if [ "$upgrade_rc" -eq 0 ] && printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'already installed\|up.to.date\|No available upgrade' >/dev/null; then
                    log_ok "Vercel CLI already up to date"
                    write_summary OK "vercel cli" "$VERCEL_VERSION"
                else
                    # Exit code first (C-F2); the output grep stays for brew upgrade (Standard 3).
                    if [ "$upgrade_rc" -ne 0 ] || printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'error\|fatal' >/dev/null; then
                        # The installed Vercel CLI still works: a warning, not an error
                        # (Standard 3); the auth check below still runs. error_reason logs
                        # the output as detail lines.
                        write_warn "vercel cli" "brew upgrade failed: $(error_reason "$UPGRADE_OUTPUT" "$upgrade_rc")"
                        write_summary OK "vercel cli" "$VERCEL_VERSION"
                    else
                        while IFS= read -r line; do log "$line"; done <<< "$UPGRADE_OUTPUT"
                        read_vercel_version
                        log_ok "Vercel CLI $VERCEL_VERSION"
                        write_summary OK "vercel cli" "$VERCEL_VERSION"
                    fi
                fi
            else
                # Not Homebrew — migrate from npm to Homebrew
                write_warn "vercel cli" "installed via npm at $vercel_path -- migrating to Homebrew"
                log "Migrating to Homebrew for Claude Code PATH compatibility..."

                # Non-blocking: brew install below proceeds; the npm copy may shadow it on PATH.
                uninstall_rc=0
                uninstall_out=$(npm uninstall -g vercel 2>&1) || uninstall_rc=$?
                if [ "$uninstall_rc" -ne 0 ]; then
                    # error_reason logs the output as detail lines (logging.md 8.2)
                    write_warn "vercel cli" "npm uninstall -g vercel failed: $(error_reason "$uninstall_out" "$uninstall_rc")"
                else
                    write_output_detail "npm-uninstall-vercel" "$uninstall_out"
                fi
                hash -r
                # brew's output streams to the console and deploy.log as it arrives and is
                # teed to a temporary file for the error reason (a failed install's output
                # is then in deploy.log twice: logging.md 8.2).
                INSTALL_OUTPUT=""
                INSTALL_RC=0
                # A failed mktemp is checked on the next line: the install then streams uncaptured
                INSTALL_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-vercelcli.XXXXXX") || INSTALL_FILE=""
                if [ -n "$INSTALL_FILE" ]; then
                    brew install vercel-cli 2>&1 | tee "$INSTALL_FILE" | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
                    INSTALL_OUTPUT=$(cat "$INSTALL_FILE")
                    rm -f "$INSTALL_FILE"
                else
                    log_detail "mktemp failed -- the brew install output is not captured; the error reason falls back to its exit code"
                    brew install vercel-cli 2>&1 | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
                fi
                if [ "$INSTALL_RC" -ne 0 ]; then
                    write_error "vercel cli" "brew install failed" "$(error_reason "$INSTALL_OUTPUT" "$INSTALL_RC")"
                elif command -v vercel &>/dev/null; then
                    read_vercel_version
                    log_ok "Migrated to Homebrew: Vercel CLI $VERCEL_VERSION"
                    log_ok "Install path: $(command -v vercel)"
                    write_summary OK "vercel cli" "$VERCEL_VERSION"
                else
                    write_error "vercel cli" "installed but not on PATH" "command -v vercel found nothing after brew install"
                fi
            fi
        else
            # Fresh install
            log "Installing Vercel CLI via Homebrew..."
            # Streamed and teed, as above
            INSTALL_OUTPUT=""
            INSTALL_RC=0
            # A failed mktemp is checked on the next line: the install then streams uncaptured
            INSTALL_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-vercelcli.XXXXXX") || INSTALL_FILE=""
            if [ -n "$INSTALL_FILE" ]; then
                brew install vercel-cli 2>&1 | tee "$INSTALL_FILE" | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
                INSTALL_OUTPUT=$(cat "$INSTALL_FILE")
                rm -f "$INSTALL_FILE"
            else
                log_detail "mktemp failed -- the brew install output is not captured; the error reason falls back to its exit code"
                brew install vercel-cli 2>&1 | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
            fi
            if [ "$INSTALL_RC" -ne 0 ]; then
                write_error "vercel cli" "brew install failed" "$(error_reason "$INSTALL_OUTPUT" "$INSTALL_RC")"
            elif command -v vercel &>/dev/null; then
                read_vercel_version
                log_ok "Vercel CLI installed ($VERCEL_VERSION)"
                log_ok "Install path: $(command -v vercel)"
                write_summary OK "vercel cli" "$VERCEL_VERSION"
            else
                write_error "vercel cli" "installed but not on PATH" "command -v vercel found nothing after brew install"
            fi
        fi
        ;;

    *)
        # Linux: npm is the only option
        if ! command -v npm &>/dev/null; then
            write_error "vercel cli" "npm not found" "npm is not on PATH -- install Node.js first (aitools install does)"
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
            hash -r
            if [ "$npm_rc" -ne 0 ]; then
                # error_reason logs the output as detail lines (logging.md 8.2)
                write_error "vercel cli" "npm install failed" "$(error_reason "$NPM_OUTPUT" "$npm_rc")"
            else
                write_output_detail "npm-install-vercel" "$NPM_OUTPUT"
                if command -v vercel &>/dev/null; then
                    read_vercel_version
                    log_ok "Vercel CLI installed ($VERCEL_VERSION)"
                    write_summary OK "vercel cli" "$VERCEL_VERSION"
                else
                    write_error "vercel cli" "installed but not on PATH" "command -v vercel found nothing after npm install -g"
                fi
            fi
        fi
        ;;
esac

# --- Auth status check (script-standards-detail.md: command exit code pattern) ---
# Gated on the script's own error count: an upgrade failure with a working CLI is a
# warning, so the check still runs after it.
if command -v vercel >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    whoami_rc=0
    whoami_out=$(vercel whoami 2>&1) || whoami_rc=$?
    if [ "$whoami_rc" -ne 0 ]; then
        write_output_detail "vercel-whoami (exit $whoami_rc)" "$whoami_out"
        write_action "vercel cli" "not authenticated -- run: vercel login" "vercel login -- authenticate vercel CLI"
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
