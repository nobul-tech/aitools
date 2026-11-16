#!/usr/bin/env bash
# setup-bash.sh -- Installs/verifies bash >= 5.0
# Safe to re-run -- detects existing install and skips if present.
#
# macOS: Installs bash 5.x via Homebrew (system bash 3.2 is GPLv2-frozen).
# Linux: Verifies system bash >= 5.0 (usually already there).
#
# See registries/tool-registry.json for install source details.

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

MIN_MAJOR=5
MIN_MINOR=0

# --- Version check helper ---
# Returns 0 if bash >= 5.0, 1 otherwise.
# Uses bash --version to parse version from any bash binary.
check_bash_version() {
    local bash_bin="${1:-bash}"
    local ver_line
    ver_line=$("$bash_bin" --version 2>/dev/null | sed -n '1p') || return 1
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
    "$bash_bin" --version 2>/dev/null | sed -n '1p' | perl -ne 'print $1 if /version\s+(\d+\.\d+\.\d+)/'
}

# --- Install/verify ---
# The platform comes from the library (AITOOLS_PLATFORM: macos / linux),
# never from a direct uname read (.claude/rules/cross-platform.md).
case "$AITOOLS_PLATFORM" in
    macos)
        # macOS: system bash is 3.2 (GPLv2-frozen). Homebrew bash is 5.x.
        if ! command -v brew &>/dev/null; then
            write_error "bash" "Homebrew not found" "brew is not on PATH"
            log "Install bash manually:"
            log "  1. Install Homebrew: https://brew.sh"
            log "  2. brew install bash"
            write_summary ACTION "" "Install Homebrew (https://brew.sh), then: brew install bash"
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
                log "#!/usr/bin/env bash resolves to the system bash"
                write_summary OK "bash" "$brew_ver"
                write_action "bash" "Homebrew bash is not first in PATH -- put $brew_prefix/bin before /usr/bin" \
                    "Put $brew_prefix/bin before /usr/bin in PATH"
            else
                # Fresh install. The output is captured (not streamed) so that a
                # failure has a reason (reference/logging.md 8.3)
                log "Installing bash via Homebrew..."
                BREW_RC=0
                BREW_OUT=$(brew install bash 2>&1) || BREW_RC=$?
                if [ "$BREW_RC" -ne 0 ]; then
                    write_error "bash" "brew install failed" "$(error_reason "$BREW_OUT" "$BREW_RC")"
                else
                    printf '%s\n' "$BREW_OUT" | while IFS= read -r line; do log "$line"; done
                fi

                if [ "$BREW_RC" -ne 0 ]; then
                    # One failure, one red line: the install error above is it
                    log "bash not checked: brew install failed"
                elif [ -x "$brew_bash" ] && check_bash_version "$brew_bash"; then
                    brew_ver=$(get_bash_version "$brew_bash")
                    log_ok "bash installed ($brew_ver) at $brew_bash"
                    write_summary OK "bash" "$brew_ver"
                else
                    write_error "bash" "installed but version check failed" \
                        "no bash >= ${MIN_MAJOR}.${MIN_MINOR} at $brew_bash"
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
                write_summary OK "bash" "$bash_ver"
                write_action "bash" "bash $bash_ver is below ${MIN_MAJOR}.${MIN_MINOR} -- upgrade it with the distribution's package manager" \
                    "Upgrade bash to >= ${MIN_MAJOR}.${MIN_MINOR}"
                log "Upgrade via your distribution's package manager:"
                log "  Debian/Ubuntu: sudo apt-get install -y bash"
                log "  Fedora/RHEL:   sudo dnf install bash"
            fi
        else
            write_error "bash" "not found" "bash is not on PATH"
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
