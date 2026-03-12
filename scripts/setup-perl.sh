#!/usr/bin/env bash
# setup-perl.sh — Installs/updates Perl
# Safe to re-run — detects existing install and skips if present.
#
# macOS: Uses Homebrew (brew install perl).
# Linux: Logs error and directs user to install via package manager.
#
# See reference/tool-registry.md for install source details.

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

OS_NAME="$(uname -s)"

# --- Version check helper ---
# Checks perl version >= 5.010. Returns 0 if OK, 1 if below minimum.
check_perl_version() {
    local ver
    ver=$(perl -e 'print $];' 2>&1)
    # perl $] returns a numeric version like 5.040000
    if perl -e 'exit($] >= 5.010 ? 0 : 1)' 2>/dev/null; then
        return 0
    else
        log_warn "Perl version $ver is below minimum 5.010"
        return 1
    fi
}

# --- Install/update ---
case "$OS_NAME" in
    Darwin)
        # macOS: Homebrew is the preferred method
        if ! command -v brew &>/dev/null; then
            log_error "Homebrew not found. Install perl manually:"
            log_error "  1. Install Homebrew: https://brew.sh"
            log_error "  2. brew install perl"
            write_summary ERROR "perl" "Homebrew not found"
            exit 1
        fi

        if command -v perl &>/dev/null; then
            perl_path="$(command -v perl)"
            perl_version="$(perl -e 'print $];')"
            log "Perl $perl_version found at $perl_path"

            # Version minimum check
            if check_perl_version; then
                write_summary OK "perl" "$perl_version"
            else
                write_summary WARN "perl" "$perl_version (below minimum 5.010)"
            fi
        else
            # Fresh install
            log "Installing Perl via Homebrew..."
            if ! brew install perl 2>&1 | while IFS= read -r line; do log "$line"; done; then
                log_error "brew install perl failed"
                write_summary ERROR "perl" "brew install failed"
            fi

            if command -v perl &>/dev/null; then
                perl_version="$(perl -e 'print $];')"
                log_ok "Perl installed (version $perl_version)"
                log_ok "Install path: $(command -v perl)"

                if check_perl_version; then
                    write_summary OK "perl" "$perl_version"
                else
                    write_summary WARN "perl" "$perl_version (below minimum 5.010)"
                fi
            else
                log_error "brew install completed but 'perl' not found in PATH"
                write_summary ERROR "perl" "installed but not on PATH"
            fi
        fi
        ;;

    *)
        # Linux: perl is usually pre-installed; if not, direct user to package manager
        if command -v perl &>/dev/null; then
            perl_version="$(perl -e 'print $];')"
            log_ok "Perl already installed (version $perl_version)"
            log "Install path: $(command -v perl)"

            if check_perl_version; then
                write_summary OK "perl" "$perl_version"
            else
                write_summary WARN "perl" "$perl_version (below minimum 5.010)"
            fi
        else
            log_error "Perl not found. Install via your distribution's package manager:"
            log_error "  Debian/Ubuntu: sudo apt-get install -y perl"
            log_error "  Fedora/RHEL:   sudo dnf install perl"
            write_summary ERROR "perl" "not found"
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
