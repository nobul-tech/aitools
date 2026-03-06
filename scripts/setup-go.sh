#!/usr/bin/env bash
# setup-go.sh -- Installs/updates Go via Homebrew (macOS)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). Removes pkg-installer and manual
#        /usr/local/go installs. Warns for goenv (user-managed).
# Windows: Uses winget -- see setup-go.ps1.
#
# See reference/tool-registry.md for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-go"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Detect provenance ---
PROVENANCE=$(detect_go_provenance)
log "Go install provenance: $PROVENANCE"

# --- Cleanup non-preferred installs ---
case "$PROVENANCE" in
    pkg-installer)
        log_warn "Go installed via macOS .pkg installer -- removing /usr/local/go/"
        if sudo rm -rf /usr/local/go; then
            log_ok "Removed /usr/local/go/"
        else
            log_warn "Failed to remove /usr/local/go/ (sudo required)"
        fi
        PROVENANCE="none"
        ;;
    manual)
        log_warn "Go installed manually at /usr/local/go/ -- removing"
        if sudo rm -rf /usr/local/go; then
            log_ok "Removed /usr/local/go/"
        else
            log_warn "Failed to remove /usr/local/go/ (sudo required)"
        fi
        PROVENANCE="none"
        ;;
    goenv)
        log_warn "Go managed by goenv -- skipping cleanup (user-managed)"
        log_warn "To switch to Homebrew: goenv uninstall <version>, then re-run this script"
        ;;
esac

# --- Install/update via Homebrew ---
if [ "$PROVENANCE" = "homebrew" ]; then
    GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
    log "Go already installed via Homebrew ($GO_VERSION) -- upgrading..."
    # brew upgrade exits non-zero when already up-to-date on some versions
    UPGRADE_OUTPUT=$(brew upgrade go 2>&1) || true
    if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'already installed\|up.to.date\|No available upgrade'; then
        log_ok "Go already up to date"
        GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
        write_summary OK "go" "$GO_VERSION"
    else
        printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
        if printf '%s\n' "$UPGRADE_OUTPUT" | grep -qi 'error\|fatal'; then
            log_error "brew upgrade go failed (see log above)"
            write_summary ERROR "go" "brew upgrade failed"
        else
            GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
            log_ok "$GO_VERSION"
            write_summary OK "go" "$GO_VERSION"
        fi
    fi
elif [ "$PROVENANCE" = "goenv" ]; then
    # goenv users manage their own Go -- just verify and report
    GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
    log_ok "Go via goenv: $GO_VERSION"
    write_summary WARN "go" "$GO_VERSION (goenv -- not Homebrew)"
else
    log "Installing Go via Homebrew..."
    if ! brew install go 2>&1 | while IFS= read -r line; do log "$line"; done; then
        log_error "brew install go failed"
        write_summary ERROR "go" "brew install failed"
    fi
    # Re-check after install
    if command -v go >/dev/null 2>&1; then
        GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
        log_ok "Go installed ($GO_VERSION)"
        write_summary OK "go" "$GO_VERSION"
    else
        log_error "brew install completed but 'go' not found in PATH"
        write_summary ERROR "go" "installed but not on PATH"
    fi
fi

# --- Ensure GOPATH/bin is on PATH ---
if ! ensure_gopath_bin_on_path; then
    GOPATH_BIN="${GOPATH:-$HOME/go}/bin"
    log_warn "Added $GOPATH_BIN to PATH for this session only"
    log_warn "For persistence, add to shell profile: export PATH=\"\$GOPATH_BIN:\$PATH\""
    write_summary ACTION "" "Add $GOPATH_BIN to PATH -- go install binaries"
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
