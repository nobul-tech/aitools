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
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

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
        # One warning, no ACTION: a goenv user may keep goenv on purpose
        write_warn "go" "managed by goenv, not Homebrew -- to switch: goenv uninstall <version>, then re-run aitools install"
        ;;
esac

# --- Install/update via Homebrew ---
if [ "$PROVENANCE" = "homebrew" ]; then
    GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
    log "Go already installed via Homebrew ($GO_VERSION) -- upgrading..."
    # brew upgrade exits non-zero when already up-to-date on some versions: the
    # output decides (Standard 3); the exit code only feeds the reason
    UPGRADE_RC=0
    UPGRADE_OUTPUT=$(brew upgrade go 2>&1) || UPGRADE_RC=$?
    if printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'already installed\|up.to.date\|No available upgrade' >/dev/null; then
        log_ok "Go already up to date"
        GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
        write_summary OK "go" "$GO_VERSION"
    elif printf '%s\n' "$UPGRADE_OUTPUT" | grep -i 'error\|fatal' >/dev/null; then
        # The existing Go still works: a warning, not an error (Standard 3).
        # error_reason logs the output as detail lines.
        write_warn "go" "brew upgrade failed: $(error_reason "$UPGRADE_OUTPUT" "$UPGRADE_RC")"
        GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
        write_summary OK "go" "$GO_VERSION"
    else
        printf '%s\n' "$UPGRADE_OUTPUT" | while IFS= read -r line; do log "$line"; done
        GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
        log_ok "$GO_VERSION"
        write_summary OK "go" "$GO_VERSION"
    fi
elif [ "$PROVENANCE" = "goenv" ]; then
    # goenv users manage their own Go -- just verify and report (its warning is above)
    GO_VERSION=$(go version 2>/dev/null || echo "version unknown")
    log_ok "Go via goenv: $GO_VERSION"
    write_summary OK "go" "$GO_VERSION"
elif [ "$PROVENANCE" = "upstream" ]; then
    # go.dev tarball at /usr/local/go (Linux): the official install -- keep it.
    # 2>/dev/null: version probe only; falls back to a placeholder string
    GO_VERSION=$(/usr/local/go/bin/go version 2>/dev/null || echo "version unknown")
    log_ok "Go via go.dev tarball at /usr/local/go ($GO_VERSION)"
    write_summary OK "go" "$GO_VERSION"
elif ! command -v brew >/dev/null 2>&1; then
    write_error "go" "Homebrew not found" "brew is not on PATH (existing installs left untouched)"
else
    log "Installing Go via Homebrew..."
    # Captured, not streamed: a failure takes its reason from the output (Standard 1)
    BREW_RC=0
    BREW_OUT=$(brew install go 2>&1) || BREW_RC=$?
    if [ "$BREW_RC" -eq 0 ]; then
        printf '%s\n' "$BREW_OUT" | while IFS= read -r line; do log "$line"; done
    fi
    # Verify the formula's own prefix (opt/Cellar), not the shared bin dir: on Intel Macs
    # $(brew --prefix)/bin is /usr/local/bin, where a symlink into /usr/local/go could
    # pass for Homebrew Go and get its target deleted below.
    # 2>/dev/null: stderr warnings must not leak into the path; || clears it on failure.
    # The -z/-x checks below are the result check.
    BREW_GO_PREFIX=$(brew --prefix go 2>/dev/null) || BREW_GO_PREFIX=""
    BREW_GO="${BREW_GO_PREFIX:+$BREW_GO_PREFIX/bin/go}"
    if [ "$BREW_RC" -ne 0 ] || [ -z "$BREW_GO" ] || [ ! -x "$BREW_GO" ]; then
        if [ "$BREW_RC" -ne 0 ]; then
            # error_reason logs the output as detail lines
            write_error "go" "brew install failed" "$(error_reason "$BREW_OUT" "$BREW_RC")"
        else
            write_error "go" "brew install failed" "Homebrew Go not found at ${BREW_GO:-the go formula prefix}"
        fi
        if [ -n "$CLEANUP_TARGET" ]; then
            # Info: the install error above is the one red line for this failure
            log "Kept existing Go at $CLEANUP_TARGET/ (replacement not verified)"
        fi
    else
        # 2>/dev/null: version probe only; falls back to a placeholder string
        GO_VERSION=$("$BREW_GO" version 2>/dev/null || echo "version unknown")
        log_ok "Go installed via Homebrew ($GO_VERSION)"
        if [ -n "$CLEANUP_TARGET" ]; then
            write_warn "go" "removing the non-preferred Go at $CLEANUP_TARGET/ ($PROVENANCE) -- Homebrew Go verified"
            RM_RC=0
            RM_OUT=$(sudo rm -rf "$CLEANUP_TARGET" 2>&1) || RM_RC=$?
            if [ "$RM_RC" -eq 0 ]; then
                log_ok "Removed $CLEANUP_TARGET/"
            else
                write_warn "go" "could not remove $CLEANUP_TARGET/ -- it may shadow Homebrew Go on PATH: $(error_reason "$RM_OUT" "$RM_RC")"
            fi
        fi
        hash -r
        if command -v go >/dev/null 2>&1; then
            write_summary OK "go" "$GO_VERSION"
        else
            write_error "go" "installed but not on PATH" "go not found on PATH after brew install"
        fi
    fi
fi

# --- GOPATH/bin on PATH ---
# Login shells get Go's bin directory from the aitools managed PATH block
# (setup-user-shell.sh), so there is nothing for the user to do here. This
# script runs as a child process: the PATH change below lasts only for this
# script, not for the user's shell or later setup steps.
if ! ensure_gopath_bin_on_path; then
    GOPATH_BIN="${GOPATH:-$HOME/go}/bin"
    log "$GOPATH_BIN is not on PATH in this shell; new login shells get it from the aitools managed block"
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
