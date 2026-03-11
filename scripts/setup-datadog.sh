#!/usr/bin/env bash
# setup-datadog.sh -- Installs/updates Datadog CLI (pup) on macOS
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew tap datadog-labs/pack (preferred).
#        Falls back to cargo install if Homebrew fails.
# Windows: Uses cargo install -- see setup-datadog.ps1.
#
# See reference/tool-registry.md for install source details.

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
    log_warn "Pup installed from old tap (datadog/pack) -- migrating to datadog-labs/pack..."
    UNINSTALL_OUTPUT=$(brew uninstall datadog/pack/pup 2>&1) || true
    printf '%s\n' "$UNINSTALL_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
    brew untap datadog/pack 2>/dev/null || true
    log_ok "Old tap removed -- will reinstall from correct tap"
    PUP_PATH=""
fi

if [ -n "$PUP_PATH" ]; then
    # Check if installed via correct Homebrew tap
    if brew list datadog-labs/pack/pup >/dev/null 2>&1; then
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log "Pup already installed via Homebrew ($PUP_VERSION) -- upgrading..."
        # brew upgrade exits non-zero when already up-to-date on some versions
        UPGRADE_OUTPUT=$(brew upgrade datadog-labs/pack/pup 2>&1) || true
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
            log_ok "Pup already up to date"
        else
            printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
            if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
                log_error "brew upgrade datadog-labs/pack/pup failed (see log above)"
                write_summary ERROR "datadog cli" "brew upgrade failed"
            else
                log_ok "Pup upgraded"
            fi
        fi
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        if [ "$ERRORS" -eq 0 ]; then
            write_summary OK "datadog cli" "$PUP_VERSION"
        fi
    else
        # Installed via go install or other method -- migrate to Homebrew
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log_warn "Pup found at $PUP_PATH ($PUP_VERSION) -- not via Homebrew, migrating..."
        # Remove old binary (likely from go install)
        if [ -f "$PUP_PATH" ]; then
            rm -f "$PUP_PATH" 2>/dev/null || log_warn "Could not remove old binary at $PUP_PATH"
        fi
        INSTALL_EC=0
        INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || INSTALL_EC=$?
        printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
        if [ "$INSTALL_EC" -ne 0 ] || printf '%s\n' "$INSTALL_OUTPUT" | grep -qi 'error\|fatal'; then
            log_error "brew install datadog-labs/pack/pup failed during migration"
            write_summary ERROR "datadog cli" "brew install failed (migration)"
        else
            PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
            log_ok "Migrated to Homebrew ($PUP_VERSION)"
        fi
        if [ "$ERRORS" -eq 0 ]; then
            PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
            write_summary OK "datadog cli" "$PUP_VERSION"
        fi
    fi
else
    # Fresh install
    log "Installing Pup via Homebrew (datadog-labs/pack tap)..."
    # brew install can exit non-zero for non-fatal warnings; check output for real errors
    INSTALL_OUTPUT=$(brew install datadog-labs/pack/pup 2>&1) || true
    printf '%s\n' "$INSTALL_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
    if printf '%s\n' "$INSTALL_OUTPUT" | grep -qi 'error\|fatal'; then
        log_warn "brew install datadog-labs/pack/pup failed -- trying cargo install fallback..."
        if command -v cargo >/dev/null 2>&1; then
            # Pre-flight: check build prerequisites
            hash -r 2>/dev/null  # Refresh command cache -- picks up tools installed by earlier steps
            PREREQ_MISSING=$(check_build_prereqs "cargo") || true
            if [ -n "$PREREQ_MISSING" ]; then
                while IFS='|' read -r prereq_name prereq_install; do
                    log_warn "$prereq_name not found -- $prereq_install"
                done <<< "$PREREQ_MISSING"
            fi
            CARGO_EC=0
            CARGO_OUTPUT=$(cargo install --git https://github.com/datadog-labs/pup 2>&1) || CARGO_EC=$?
            printf '%s\n' "$CARGO_OUTPUT" | while IFS= read -r line; do [ -n "$line" ] && log "$line"; done
            if [ "$CARGO_EC" -ne 0 ]; then
                # Diagnose: scan for known failure signatures
                DIAGNOSIS=$(diagnose_build_failure "$CARGO_OUTPUT") || true
                if [ -n "$DIAGNOSIS" ]; then
                    DIAG_NAME="${DIAGNOSIS%%|*}"
                    DIAG_REMEDY="${DIAGNOSIS#*|}"
                    log_error "Build failed: $DIAG_NAME not available"
                    log_error "Fix: $DIAG_REMEDY"
                    write_summary ERROR "datadog cli" "build failed: $DIAG_NAME missing"
                    write_summary ACTION "" "$DIAG_REMEDY -- then re-run"
                else
                    log_error "cargo install pup also failed (exit code $CARGO_EC)"
                    write_summary ERROR "datadog cli" "install failed (brew + cargo)"
                fi
            else
                log_ok "Pup installed via cargo install fallback"
            fi
        else
            log_error "cargo not found -- no fallback available"
            write_summary ERROR "datadog cli" "install failed (no cargo fallback)"
        fi
    fi
    # Re-check after install
    if command -v pup >/dev/null 2>&1; then
        PUP_VERSION=$(pup version 2>/dev/null || echo "version unknown")
        log_ok "Pup installed ($PUP_VERSION)"
        if [ "$ERRORS" -eq 0 ]; then
            write_summary OK "datadog cli" "$PUP_VERSION"
        fi
    elif [ "$ERRORS" -eq 0 ]; then
        log_error "Install completed but 'pup' not found in PATH"
        write_summary ERROR "datadog cli" "installed but not on PATH"
    fi
fi

# --- Auth status check ---
# pup auth status exits 0 regardless; check output content for auth state
if command -v pup >/dev/null 2>&1 && [ "$ERRORS" -eq 0 ]; then
    AUTH_OUTPUT=$(pup auth status 2>&1) || true
    if printf '%s\n' "$AUTH_OUTPUT" | grep -qi 'not authenticated'; then
        log_warn "Not authenticated: run 'pup auth login' (one-time OAuth)"
        write_summary WARN "datadog cli" "not authenticated"
        write_summary ACTION "" "pup auth login -- authenticate Datadog CLI"
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
