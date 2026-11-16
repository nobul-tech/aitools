#!/usr/bin/env bash
# setup-perl.sh — Installs/updates Perl
# Safe to re-run — detects existing install and skips if present.
#
# macOS: Uses Homebrew (brew install perl).
# Linux: Logs error and directs user to install via package manager.
#
# See the /tool-registry skill (registries/tool-registry.json) for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-perl"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

# --- Version check helper ---
# Checks perl version >= 5.010 and writes a warning when it is below. Always
# returns 0: a perl below the minimum still works, so the caller writes its OK
# status either way (script-standards-detail "Severity decision guide").
check_perl_version() {
    local ver
    ver=$(perl -e 'print $];' 2>&1)
    # perl $] returns a numeric version like 5.040000
    # 2>/dev/null: only the exit status is read; a perl that cannot run the
    # comparison is reported as below the minimum
    if ! perl -e 'exit($] >= 5.010 ? 0 : 1)' 2>/dev/null; then
        write_warn "perl" "version $ver is below the minimum 5.010"
    fi
    return 0
}

# --- Install/update ---
case "$AITOOLS_PLATFORM" in
    macos)
        # macOS: Homebrew is the preferred method
        if ! command -v brew &>/dev/null; then
            write_error "perl" "Homebrew not found" "brew is not on PATH"
            log "Install perl manually:"
            log "  1. Install Homebrew: https://brew.sh"
            log "  2. brew install perl"
            exit 1
        fi

        if command -v perl &>/dev/null; then
            perl_path="$(command -v perl)"
            perl_version="$(perl -e 'print $];')"
            log "Perl $perl_version found at $perl_path"

            # Version minimum check (a warning when below; the OK status either way)
            check_perl_version
            write_summary OK "perl" "$perl_version"
        else
            # Fresh install
            log "Installing Perl via Homebrew..."
            # Stream the install to the console and tee it to a file, so a
            # failure has output to take its reason from (logging.md 8.2: on a
            # failure the output is in deploy.log twice, streamed and as detail).
            # Under pipefail the pipeline's status is brew's: tee and the loop exit 0.
            CMD_OUT=""
            CMD_RC=0
            CMD_FILE=$(mktemp "${TMPDIR:-/tmp}/setup-perl.XXXXXX") || CMD_FILE=""
            if [ -n "$CMD_FILE" ]; then
                brew install perl 2>&1 | tee "$CMD_FILE" | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
                CMD_OUT=$(cat "$CMD_FILE")
                rm -f "$CMD_FILE"
            else
                # mktemp failed: stream as before; the reason falls back to "no output (exit N)"
                brew install perl 2>&1 | while IFS= read -r line; do log "$line"; done || CMD_RC=$?
            fi
            if [ "$CMD_RC" -ne 0 ]; then
                # || CMD_REASON="": error_reason runs perl, and exits 127 when perl
                # is missing (this branch); the empty result is checked next
                CMD_REASON=$(error_reason "$CMD_OUT" "$CMD_RC") || CMD_REASON=""
                if [ -z "$CMD_REASON" ]; then
                    # No perl, so no reason from error_reason:
                    # the first error line of the output, else its last non-empty
                    # line, else the exit code (logging.md 8.3 rules 3-5); the
                    # output itself is already in deploy.log (streamed above)
                    # || true: grep exits 1 when no line matches (pipefail); the
                    # empty result is checked on the next line
                    CMD_REASON=$(printf '%s\n' "$CMD_OUT" | grep -i -E '(^| )[A-Za-z0-9_-]*error:|(^| )fatal:' | sed -n -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '1p') || true
                    if [ -z "$CMD_REASON" ]; then
                        CMD_REASON=$(printf '%s\n' "$CMD_OUT" | sed -n -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/./h' -e '${x;p;}')
                    fi
                    if [ -z "$CMD_REASON" ]; then CMD_REASON="no output (exit $CMD_RC)"; fi
                fi
                write_error "perl" "brew install failed" "$CMD_REASON"
            fi

            if command -v perl &>/dev/null; then
                perl_version="$(perl -e 'print $];')"
                log_ok "Perl installed (version $perl_version)"
                log_ok "Install path: $(command -v perl)"

                check_perl_version
                write_summary OK "perl" "$perl_version"
            elif [ "$CMD_RC" -ne 0 ]; then
                # One failed install, one red line: the brew error above is the cause
                log "perl not on PATH after the failed install"
            else
                write_error "perl" "installed but not on PATH" "command -v perl found nothing after brew install"
            fi
        fi
        ;;

    *)
        # Linux: perl is usually pre-installed; if not, direct user to package manager
        if command -v perl &>/dev/null; then
            perl_version="$(perl -e 'print $];')"
            log_ok "Perl already installed (version $perl_version)"
            log "Install path: $(command -v perl)"

            check_perl_version
            write_summary OK "perl" "$perl_version"
        else
            write_error "perl" "not found" "perl is not on PATH (this script installs perl only on macOS)"
            log "Install perl via your distribution's package manager:"
            log "  Debian/Ubuntu: sudo apt-get install -y perl"
            log "  Fedora/RHEL:   sudo dnf install perl"
            write_summary ACTION "" "Install perl via package manager"
        fi
        ;;
esac

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
