#!/usr/bin/env bash
# setup-rust.sh — Installs/updates Rust toolchain (rustup + cargo)
# Safe to re-run — detects existing install and upgrades as needed.
#
# macOS/Linux: Uses rustup (curl installer) for toolchain management.
#              If rust was previously installed via Homebrew (brew install rust),
#              removes it and installs via rustup instead.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
    write_warn "rust/cargo" "Homebrew rust found ($brew_rust; conflicts with rustup) -- removing it"
    uninstall_rc=0
    uninstall_out=$(brew uninstall rust 2>&1) || uninstall_rc=$?
    if [ "$uninstall_rc" -ne 0 ]; then
        # Non-blocking: rustup installs alongside; the brew copy may shadow it on PATH.
        # error_reason logs the output as detail lines (logging.md 8.2).
        write_warn "rust/cargo" "brew uninstall rust failed: $(error_reason "$uninstall_out" "$uninstall_rc")"
    else
        while IFS= read -r line; do
            if [ -n "${line// /}" ]; then log_detail "brew-uninstall-rust: $line"; fi
        done <<< "$uninstall_out"
    fi
fi

# --- Install/update ---
if command -v rustup &>/dev/null; then
    log "rustup found — updating toolchain..."
    # Exit code decides (C-F2); the full output goes to the log as detail.
    update_rc=0
    RUSTUP_OUTPUT=$(rustup update 2>&1) || update_rc=$?
    if [ "$update_rc" -ne 0 ]; then
        # The installed toolchain still works: a warning, not an error (script-standards
        # Standard 3). error_reason logs the output as detail lines.
        write_warn "rust/cargo" "rustup update failed: $(error_reason "$RUSTUP_OUTPUT" "$update_rc")"
        write_summary OK "rust/cargo" "$(cargo --version 2>&1)"
    else
        while IFS= read -r line; do
            if [ -n "${line// /}" ]; then log_detail "rustup-update: $line"; fi
        done <<< "$RUSTUP_OUTPUT"
        log_ok "cargo $(cargo --version 2>&1)"
        log_ok "rustc $(rustc --version 2>&1)"
        write_summary OK "rust/cargo" "$(cargo --version 2>&1)"
    fi
else
    log "Installing Rust toolchain via rustup..."
    # The installer's output streams to the console and deploy.log as it arrives and
    # is teed to a temporary file for the error reason (a failed install's output is
    # then in deploy.log twice: logging.md 8.2). The brace group's 2>&1 takes curl's
    # own stderr into the stream; pipefail gives curl's exit code when the download fails.
    INSTALL_OUTPUT=""
    INSTALL_RC=0
    # A failed mktemp is checked on the next line: the install then streams uncaptured
    INSTALL_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-rust.XXXXXX") || INSTALL_FILE=""
    if [ -n "$INSTALL_FILE" ]; then
        { curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; } 2>&1 | tee "$INSTALL_FILE" | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
        INSTALL_OUTPUT=$(cat "$INSTALL_FILE")
        rm -f "$INSTALL_FILE"
    else
        log_detail "mktemp failed -- the rustup installer output is not captured; the error reason falls back to its exit code"
        { curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; } 2>&1 | while IFS= read -r line; do log "$line"; done || INSTALL_RC=$?
    fi
    if [ "$INSTALL_RC" -ne 0 ]; then
        write_error "rust/cargo" "rustup install failed" "$(error_reason "$INSTALL_OUTPUT" "$INSTALL_RC")"
    fi

    # Re-source env in case PATH was just configured
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

    if command -v cargo &>/dev/null; then
        log_ok "Rust toolchain installed"
        log_ok "cargo $(cargo --version 2>&1)"
        log_ok "rustc $(rustc --version 2>&1)"
        # rustup --version prints an "info:" line on stderr; keep only the version line.
        log_ok "$(grep -m1 '^rustup ' <<< "$(rustup --version 2>&1)")"
        write_summary OK "rust/cargo" "$(cargo --version 2>&1)"
    elif [ "$INSTALL_RC" -ne 0 ]; then
        # One failure, one red line: the install error above is the cause
        log "cargo not on PATH after the failed rustup install"
    else
        write_error "rust/cargo" "installed but cargo not on PATH" "cargo is not in ~/.cargo/bin"
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
