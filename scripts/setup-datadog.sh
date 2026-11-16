#!/usr/bin/env bash
# setup-datadog.sh -- Installs/updates Datadog CLI (pup) on macOS/Linux
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew tap datadog-labs/pack (preferred).
#        Falls back to cargo install when Homebrew is unavailable or the tap
#        install does not produce `pup` (judged by the binary, not by output text).
#        A non-Homebrew pup is replaced only after the Homebrew copy is verified.
# Linux: cargo fallback until Linux support lands (nobul-tech/aitools#14).
# Windows: Uses cargo install -- see setup-datadog.ps1.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-datadog"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Detect existing install ---
PUP_PATH=$(command -v pup 2>/dev/null) || PUP_PATH=""

# --- Migrate old Homebrew tap (datadog/pack -> datadog-labs/pack) ---
if [ -n "$PUP_PATH" ] && brew list datadog/pack/pup >/dev/null 2>&1; then
    write_warn "datadog cli" "installed from the old tap datadog/pack -- migrating to datadog-labs/pack"
    UNINSTALL_EC=0
    # || records brew's exit status; checked below
    UNINSTALL_OUTPUT=$(brew uninstall datadog/pack/pup 2>&1) || UNINSTALL_EC=$?
    if [ "$UNINSTALL_EC" -ne 0 ]; then
        # error_reason logs the output as detail lines
        write_warn "datadog cli" "brew uninstall datadog/pack/pup failed: $(error_reason "$UNINSTALL_OUTPUT" "$UNINSTALL_EC") -- reinstalling from datadog-labs/pack anyway"
    else
        printf '%s\n' "$UNINSTALL_OUTPUT" | while IFS= read -r line; do
            if [ -n "$line" ]; then log "$line"; fi
        done
    fi
    # A leftover tap entry is harmless (the formula is gone); report it, do not fail
    UNTAP_RC=0
    # || records brew's exit status; checked below
    UNTAP_OUT=$(brew untap datadog/pack 2>&1) || UNTAP_RC=$?
    if [ "$UNTAP_RC" -ne 0 ]; then
        write_warn "datadog cli" "could not untap datadog/pack (left in place): $(error_reason "$UNTAP_OUT" "$UNTAP_RC")"
    else
        printf '%s\n' "$UNTAP_OUT" | while IFS= read -r line; do
            if [ -n "$line" ]; then log "$line"; fi
        done
    fi
    log_ok "Old tap removed -- will reinstall from correct tap"
    PUP_PATH=""
fi

if [ -n "$PUP_PATH" ]; then
    # Check if installed via correct Homebrew tap
    if brew list datadog-labs/pack/pup >/dev/null 2>&1; then
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log "Pup already installed via Homebrew ($PUP_VERSION) -- upgrading..."
        # brew upgrade exits non-zero when already up-to-date on some versions, so
        # the output decides failure (Standard 3); the exit status feeds the reason
        UPGRADE_RC=0
        UPGRADE_OUTPUT=$(brew upgrade datadog-labs/pack/pup 2>&1) || UPGRADE_RC=$?
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'already installed\|up.to.date\|No available upgrade' >/dev/null; then
            log_ok "Pup already up to date"
        elif printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'error\|fatal' >/dev/null; then
            # The installed pup still works: a warning, not an error (Standard 3).
            # error_reason logs the output as detail lines.
            write_warn "datadog cli" "brew upgrade failed: $(error_reason "$UPGRADE_OUTPUT" "$UPGRADE_RC")"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            log_ok "Pup upgraded"
        fi
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        if [ "$ERRORS" -eq 0 ]; then
            write_summary OK "datadog cli" "$PUP_VERSION"
        fi
    else
        # Installed via go install or another method -- migrate to Homebrew.
        # Install first; remove the old binary only after the Homebrew copy is verified.
        # 2>/dev/null: version probe only; falls back to a placeholder string
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        if ! command -v brew >/dev/null 2>&1; then
            log "Pup found at $PUP_PATH ($PUP_VERSION)"
            write_summary OK "datadog cli" "$PUP_VERSION"
            write_warn "datadog cli" "pup at $PUP_PATH is not from Homebrew and Homebrew is not available -- kept"
        else
            write_warn "datadog cli" "pup at $PUP_PATH is not from Homebrew -- migrating to Homebrew"
            INSTALL_EC=0
            # || records brew's exit status; the binary check below decides success
            INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || INSTALL_EC=$?
            BREW_PUP="$(brew --prefix)/bin/pup"
            if [ ! -x "$BREW_PUP" ]; then
                # The old pup still works, so this is a warning, not a failure.
                # error_reason logs the output as detail lines (the last line when
                # brew exited 0 without producing the binary).
                write_summary OK "datadog cli" "$PUP_VERSION"
                write_warn "datadog cli" "migration to Homebrew failed, kept $PUP_PATH: $(error_reason "$INSTALL_OUTPUT" "$INSTALL_EC")"
            else
                printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do
                    if [ -n "$line" ]; then log "$line"; fi
                done
                if [ "$PUP_PATH" != "$BREW_PUP" ] && [ -f "$PUP_PATH" ]; then
                    RM_RC=0
                    # || records rm's exit status; checked below
                    RM_OUT=$(rm -f "$PUP_PATH" 2>&1) || RM_RC=$?
                    if [ "$RM_RC" -eq 0 ]; then
                        log "Removed old binary $PUP_PATH"
                    else
                        write_warn "datadog cli" "could not remove the old binary $PUP_PATH: $(error_reason "$RM_OUT" "$RM_RC")"
                    fi
                fi
                # 2>/dev/null: version probe only; falls back to a placeholder string
                PUP_VERSION=$("$BREW_PUP" version 2>/dev/null || echo "version unknown")
                log_ok "Migrated to Homebrew ($PUP_VERSION)"
                write_summary OK "datadog cli" "$PUP_VERSION"
            fi
        fi
    fi
else
    # Fresh install: Homebrew tap when available, else build from source with cargo.
    # Success is judged by `pup` being on PATH afterwards -- not by grepping output
    # (brew can exit non-zero on non-fatal warnings; a missing brew prints neither word).
    BREW_TRIED=false
    INSTALL_EC=0
    INSTALL_OUTPUT=""
    if command -v brew >/dev/null 2>&1; then
        BREW_TRIED=true
        log "Installing Pup via Homebrew (datadog-labs/pack tap)..."
        # || records brew's exit status; the binary check below decides success
        INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || INSTALL_EC=$?
        if [ "$INSTALL_EC" -eq 0 ]; then
            printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do
                if [ -n "$line" ]; then log "$line"; fi
            done
        fi
        log "brew install exit code: $INSTALL_EC"
    else
        log "Homebrew not found -- skipping the datadog-labs/pack tap"
    fi
    hash -r
    if ! command -v pup >/dev/null 2>&1; then
        if ! $BREW_TRIED; then
            write_warn "datadog cli" "Homebrew is not available -- trying cargo install"
        elif [ "$INSTALL_EC" -ne 0 ]; then
            # error_reason logs the brew output as detail lines
            write_warn "datadog cli" "Homebrew did not install pup -- trying cargo install: $(error_reason "$INSTALL_OUTPUT" "$INSTALL_EC")"
        else
            write_warn "datadog cli" "Homebrew did not install pup -- trying cargo install"
        fi
        if command -v cargo >/dev/null 2>&1; then
            # Pre-flight (Layer 1): check build prerequisites; skip the build when any is missing
            hash -r 2>/dev/null  # Refresh command cache -- picks up tools installed by earlier steps
            # || true: check_build_prereqs returns 1 when a prerequisite is missing; its
            # output (one NAME|INSTALL line each) is the result checked below
            PREREQ_MISSING=$(check_build_prereqs "cargo") || true
            if [ -n "$PREREQ_MISSING" ]; then
                PREREQ_NAMES=""
                while IFS='|' read -r prereq_name prereq_install; do
                    PREREQ_NAMES="${PREREQ_NAMES:+$PREREQ_NAMES, }$prereq_name"
                    log "$prereq_name not installed -- required to build pup from source"
                    write_summary ACTION "" "$prereq_install -- then re-run aitools install"
                done <<< "$PREREQ_MISSING"
                write_error "datadog cli" "missing build prereqs" "$PREREQ_NAMES not installed"
            else
                CARGO_EC=0
                CARGO_OUTPUT=$(cargo install --git https://github.com/datadog-labs/pup 2>&1) || CARGO_EC=$?
                if [ "$CARGO_EC" -ne 0 ]; then
                    # Layer 2: error_reason tries the known build signatures first and
                    # logs the output as detail lines
                    write_error "datadog cli" "cargo install failed" "$(error_reason "$CARGO_OUTPUT" "$CARGO_EC")"
                    # || true: diagnose_build_failure returns 1 when no signature matches;
                    # the empty DIAGNOSIS is the result checked below
                    DIAGNOSIS=$(diagnose_build_failure "$CARGO_OUTPUT") || true
                    if [ -n "$DIAGNOSIS" ]; then
                        write_summary ACTION "" "${DIAGNOSIS#*|} -- then re-run aitools install"
                    fi
                else
                    printf '%s\n' "$CARGO_OUTPUT" | while IFS= read -r line; do
                        if [ -n "$line" ]; then log "$line"; fi
                    done
                    log_ok "Pup installed via cargo install fallback"
                fi
            fi
        else
            write_error "datadog cli" "install failed" "Homebrew did not install pup and cargo is not available for the fallback"
        fi
    fi
    # Re-check after install
    if command -v pup >/dev/null 2>&1; then
        if $BREW_TRIED && [ "$INSTALL_EC" -ne 0 ]; then
            # brew exited non-zero but produced pup (non-fatal warnings): its output
            # was not logged above
            printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do
                if [ -n "$line" ]; then log "$line"; fi
            done
        fi
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log_ok "Pup installed ($PUP_VERSION)"
        if [ "$ERRORS" -eq 0 ]; then
            write_summary OK "datadog cli" "$PUP_VERSION"
        fi
    elif [ "$ERRORS" -eq 0 ]; then
        write_error "datadog cli" "installed but not on PATH" "pup not found after the install"
    fi
fi

# --- Auth status check ---
# pup auth status exits 0 regardless; check output content for auth state
# Tokens are site-scoped. Install runs without shell profile, so DD_SITE may be unset
# while the user authenticated with us5 via shared/shell/aliases.sh — default must match.
if [ -z "${DD_SITE:-}" ]; then
    export DD_SITE="us5.datadoghq.com"
fi
if command -v pup >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    AUTH_OUTPUT=$(pup auth status 2>&1) || true
    if printf '%s\n' "$AUTH_OUTPUT" | grep -i 'not authenticated' >/dev/null; then
        write_action "datadog cli" "not authenticated -- run: pup auth login (one-time OAuth)" \
            "pup auth login -- authenticate Datadog CLI"
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
