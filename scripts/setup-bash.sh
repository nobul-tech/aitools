#!/usr/bin/env bash
# setup-bash.sh -- Installs/verifies bash >= 5.0
# Safe to re-run -- detects existing install and skips if present.
#
# macOS: Installs bash 5.x via Homebrew (system bash 3.2 is GPLv2-frozen).
# Linux: Verifies system bash >= 5.0 (usually already there).
#
# See reference/tool-registry.json for install source details.

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-bash"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

OS_NAME="$(uname -s)"
MIN_MAJOR=5
MIN_MINOR=0

# --- Version check helper ---
# Returns 0 if bash >= 5.0, 1 otherwise.
# Uses bash --version to parse version from any bash binary.
check_bash_version() {
    local bash_bin="${1:-bash}"
    local ver_line
    ver_line=$("$bash_bin" --version 2>/dev/null | head -1) || return 1
    # Extract version like "5.2.37" from "GNU bash, version 5.2.37(1)-release ..."
    local ver
    ver=$(printf '%s' "$ver_line" | perl -ne 'print $1 if /version\s+(\d+\.\d+)/')
    if [ -z "$ver" ]; then
        return 1
    fi
    local major minor
    major=$(printf '%s' "$ver" | cut -d. -f1)
    minor=$(printf '%s' "$ver" | cut -d. -f2)
    if [ "$major" -gt "$MIN_MAJOR" ] || { [ "$major" -eq "$MIN_MAJOR" ] && [ "$minor" -ge "$MIN_MINOR" ]; }; then
        return 0
    fi
    return 1
}

# --- Get version string ---
get_bash_version() {
    local bash_bin="${1:-bash}"
    "$bash_bin" --version 2>/dev/null | head -1 | perl -ne 'print $1 if /version\s+(\d+\.\d+\.\d+)/'
}

# --- Install/verify ---
case "$OS_NAME" in
    Darwin)
        # macOS: system bash is 3.2 (GPLv2-frozen). Homebrew bash is 5.x.
        if ! command -v brew &>/dev/null; then
            log_error "Homebrew not found. Install bash manually:"
            log_error "  1. Install Homebrew: https://brew.sh"
            log_error "  2. brew install bash"
            write_summary ERROR "bash" "Homebrew not found"
            exit 1
        fi

        # Check if env-resolved bash is already >= 5.0
        if check_bash_version bash; then
            bash_ver=$(get_bash_version bash)
            bash_path="$(command -v bash)"
            log_ok "bash $bash_ver at $bash_path (>= ${MIN_MAJOR}.${MIN_MINOR})"
            write_summary OK "bash" "$bash_ver"
        else
            system_ver=$(get_bash_version /bin/bash)
            log "System bash is $system_ver (below minimum ${MIN_MAJOR}.${MIN_MINOR})"

            # Check if Homebrew bash is already installed but not first in PATH
            brew_prefix="$(brew --prefix 2>/dev/null)"
            brew_bash="${brew_prefix}/bin/bash"
            if [ -x "$brew_bash" ] && check_bash_version "$brew_bash"; then
                brew_ver=$(get_bash_version "$brew_bash")
                log_ok "Homebrew bash $brew_ver already installed at $brew_bash"
                log_warn "Homebrew bash is not first in PATH -- #!/usr/bin/env bash resolves to system bash"
                log "Ensure $brew_prefix/bin is before /usr/bin in PATH"
                write_summary WARN "bash" "$brew_ver (PATH ordering issue)"
            else
                # Fresh install
                log "Installing bash via Homebrew..."
                if ! brew install bash 2>&1 | while IFS= read -r line; do log "$line"; done; then
                    log_error "brew install bash failed"
                    write_summary ERROR "bash" "brew install failed"
                fi

                if [ -x "$brew_bash" ] && check_bash_version "$brew_bash"; then
                    brew_ver=$(get_bash_version "$brew_bash")
                    log_ok "bash installed ($brew_ver) at $brew_bash"
                    write_summary OK "bash" "$brew_ver"
                else
                    log_error "brew install completed but bash >= ${MIN_MAJOR}.${MIN_MINOR} not found"
                    write_summary ERROR "bash" "installed but version check failed"
                fi
            fi
        fi
        ;;

    *)
        # Linux: bash is usually >= 5.0 on modern distros
        if command -v bash &>/dev/null; then
            if check_bash_version bash; then
                bash_ver=$(get_bash_version bash)
                log_ok "bash $bash_ver (>= ${MIN_MAJOR}.${MIN_MINOR})"
                write_summary OK "bash" "$bash_ver"
            else
                bash_ver=$(get_bash_version bash)
                log_warn "bash $bash_ver is below minimum ${MIN_MAJOR}.${MIN_MINOR}"
                log "Upgrade via your distribution's package manager:"
                log "  Debian/Ubuntu: sudo apt-get install -y bash"
                log "  Fedora/RHEL:   sudo dnf install bash"
                write_summary WARN "bash" "$bash_ver (below minimum ${MIN_MAJOR}.${MIN_MINOR})"
                write_summary ACTION "" "Upgrade bash to >= ${MIN_MAJOR}.${MIN_MINOR}"
            fi
        else
            log_error "bash not found"
            write_summary ERROR "bash" "not found"
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
