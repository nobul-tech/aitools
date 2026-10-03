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
# Homebrew "rust" formula is a brew-managed toolchain that conflicts with rustup.
# `brew list --versions rust` exits non-zero when the formula is not installed.
if command -v brew &>/dev/null && brew_rust=$(brew list --versions rust 2>&1); then
    log_warn "Found Homebrew-managed rust ($brew_rust; conflicts with rustup). Removing..."
    uninstall_rc=0
    uninstall_out=$(brew uninstall rust 2>&1) || uninstall_rc=$?
    while IFS= read -r line; do
        if [ -n "${line// /}" ]; then log_detail "brew-uninstall-rust: $line"; fi
    done <<< "$uninstall_out"
    if [ "$uninstall_rc" -ne 0 ]; then
        # Non-blocking: rustup installs alongside; the brew copy may shadow it on PATH.
        log_warn "brew uninstall rust failed (exit $uninstall_rc) -- see $(display_path "$LOG_FILE")"
    fi
fi

# --- Install/update ---
if command -v rustup &>/dev/null; then
    log "rustup found — updating toolchain..."
    # Exit code decides (C-F2); the full output goes to the log as detail.
    update_rc=0
    RUSTUP_OUTPUT=$(rustup update 2>&1) || update_rc=$?
    while IFS= read -r line; do
        if [ -n "${line// /}" ]; then log_detail "rustup-update: $line"; fi
    done <<< "$RUSTUP_OUTPUT"
    if [ "$update_rc" -ne 0 ]; then
        log_error "rustup update failed (exit $update_rc) -- see $(display_path "$LOG_FILE")"
        write_summary ERROR "rust/cargo" "rustup update failed (exit $update_rc)"
    else
        log_ok "cargo $(cargo --version 2>&1)"
        log_ok "rustc $(rustc --version 2>&1)"
        write_summary OK "rust/cargo" "$(cargo --version 2>&1)"
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
        log_ok "cargo $(cargo --version 2>&1)"
        log_ok "rustc $(rustc --version 2>&1)"
        # rustup --version prints an "info:" line on stderr; keep only the version line.
        log_ok "$(rustup --version 2>&1 | grep -m1 '^rustup ')"
        write_summary OK "rust/cargo" "$(cargo --version 2>&1)"
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
