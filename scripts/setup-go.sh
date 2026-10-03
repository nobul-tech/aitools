#!/usr/bin/env bash
# setup-go.sh -- Installs/updates Go via Homebrew (macOS); keeps go.dev installs (Linux)
# Safe to re-run -- detects existing install and upgrades as needed.
#
# macOS: Uses Homebrew (preferred). Replaces pkg-installer and manual
#        /usr/local/go installs, removing them only after Homebrew Go is
#        verified (install first, clean up second). Warns for goenv (user-managed).
# Linux: Keeps the go.dev tarball at /usr/local/go (the official install).
#        Other Linux install paths arrive with Linux support (nobul-tech/aitools#14).
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

# --- Non-preferred installs: replace first, clean up only after verification ---
# A failed or unavailable replacement must never leave the machine without Go.
CLEANUP_TARGET=""
case "$PROVENANCE" in
    pkg-installer|manual)
        CLEANUP_TARGET="/usr/local/go"
        log "Go at /usr/local/go/ ($PROVENANCE) will be replaced by Homebrew Go, then removed"
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
elif [ "$PROVENANCE" = "upstream" ]; then
    # go.dev tarball at /usr/local/go (Linux): the official install -- keep it.
    # 2>/dev/null: version probe only; falls back to a placeholder string
    GO_VERSION=$(/usr/local/go/bin/go version 2>/dev/null || echo "version unknown")
    log_ok "Go via go.dev tarball at /usr/local/go ($GO_VERSION)"
    write_summary OK "go" "$GO_VERSION"
elif ! command -v brew >/dev/null 2>&1; then
    log_error "Homebrew not found -- cannot install Go via Homebrew (existing installs left untouched)"
    write_summary ERROR "go" "Homebrew not found"
else
    log "Installing Go via Homebrew..."
    BREW_RC=0
    # || records the pipeline status (pipefail) so set -e does not abort before it is reported
    brew install go 2>&1 | while IFS= read -r line; do log "$line"; done || BREW_RC=$?
    # Verify the formula's own prefix (opt/Cellar), not the shared bin dir: on Intel Macs
    # $(brew --prefix)/bin is /usr/local/bin, where a symlink into /usr/local/go could
    # pass for Homebrew Go and get its target deleted below.
    # 2>/dev/null: stderr warnings must not leak into the path; || clears it on failure.
    # The -z/-x checks below are the result check.
    BREW_GO_PREFIX=$(brew --prefix go 2>/dev/null) || BREW_GO_PREFIX=""
    BREW_GO="${BREW_GO_PREFIX:+$BREW_GO_PREFIX/bin/go}"
    if [ "$BREW_RC" -ne 0 ] || [ -z "$BREW_GO" ] || [ ! -x "$BREW_GO" ]; then
        log_error "brew install go failed (exit $BREW_RC) -- Homebrew Go not available"
        write_summary ERROR "go" "brew install failed"
        if [ -n "$CLEANUP_TARGET" ]; then
            log_warn "Kept existing Go at $CLEANUP_TARGET/ (replacement not verified)"
        fi
    else
        # 2>/dev/null: version probe only; falls back to a placeholder string
        GO_VERSION=$("$BREW_GO" version 2>/dev/null || echo "version unknown")
        log_ok "Go installed via Homebrew ($GO_VERSION)"
        if [ -n "$CLEANUP_TARGET" ]; then
            log_warn "Removing non-preferred Go at $CLEANUP_TARGET/ ($PROVENANCE) -- Homebrew Go verified"
            if sudo rm -rf "$CLEANUP_TARGET"; then
                log_ok "Removed $CLEANUP_TARGET/"
            else
                log_warn "Failed to remove $CLEANUP_TARGET/ (sudo required) -- it may shadow Homebrew Go on PATH"
            fi
        fi
        hash -r
        if command -v go >/dev/null 2>&1; then
            write_summary OK "go" "$GO_VERSION"
        else
            log_error "Go installed but 'go' not found in PATH"
            write_summary ERROR "go" "installed but not on PATH"
        fi
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
