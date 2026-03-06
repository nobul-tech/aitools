#!/usr/bin/env bash
# setup-rust.sh — Installs/updates Rust toolchain (rustup + cargo)
# Safe to re-run — detects existing install and upgrades as needed.
#
# macOS/Linux: Uses rustup (curl installer) for toolchain management.
#              If rust was previously installed via Homebrew (brew install rust),
#              removes it and installs via rustup instead.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-rust"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# Ensure ~/.cargo/bin is in PATH for this session
export PATH="$HOME/.cargo/bin:$PATH"

# --- Cleanup non-preferred installs ---
# Homebrew "rust" formula is a brew-managed toolchain that conflicts with rustup
if command -v brew &>/dev/null && brew list rust &>/dev/null 2>&1; then
    log_warn "Found Homebrew-managed rust (conflicts with rustup). Removing..."
    # Cleanup: brew uninstall may fail if formula not fully installed; log warning only
    brew uninstall rust 2>/dev/null || log_warn "Failed to uninstall brew rust"
fi

# --- Install/update ---
if command -v rustup &>/dev/null; then
    log "rustup found — updating toolchain..."
    RUSTUP_OUTPUT=$(rustup update 2>&1) || true
    printf '%s\n' "$RUSTUP_OUTPUT" | tail -3 | while IFS= read -r line; do [ -n "${line// /}" ] && log "$line"; done
    if printf '%s\n' "$RUSTUP_OUTPUT" | grep -qi 'error\|fatal'; then
        log_error "rustup update reported errors (see log above)"
        write_summary ERROR "rust/cargo" "rustup update failed"
    else
        log_ok "cargo $(cargo --version 2>/dev/null)"
        log_ok "rustc $(rustc --version 2>/dev/null)"
        write_summary OK "rust/cargo" "$(cargo --version 2>/dev/null)"
    fi
else
    log "Installing Rust toolchain via rustup..."
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1 | while IFS= read -r line; do log "$line"; done; then
        log_error "rustup installer failed"
        write_summary ERROR "rust/cargo" "rustup install failed"
    fi

    # Re-source env in case PATH was just configured
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

    if command -v cargo &>/dev/null; then
        log_ok "Rust toolchain installed"
        log_ok "cargo $(cargo --version 2>/dev/null)"
        log_ok "rustc $(rustc --version 2>/dev/null)"
        log_ok "rustup $(rustup --version 2>/dev/null | head -1)"
        write_summary OK "rust/cargo" "$(cargo --version 2>/dev/null)"
    else
        log_error "rustup install completed but 'cargo' not found in PATH"
        log_error "Expected location: ~/.cargo/bin"
        write_summary ERROR "rust/cargo" "installed but cargo not on PATH"
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
