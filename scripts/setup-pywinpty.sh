#!/usr/bin/env bash
# setup-pywinpty.sh -- pywinpty on macOS and Linux: not applicable
# pywinpty is the Windows ConPTY backend of the pty test runner
# (tests/managed-files/pty-run.py); on macOS and Linux the runner uses the stdlib pty
# module, so there is nothing to install. This script reports one OK row
# "n/a (<platform>)" and exits; it exists so the .sh/.ps1 pair is complete and both
# installers run the same step. The real install is setup-pywinpty.ps1 (Windows).
# Safe to re-run -- changes nothing.
# Platform: macOS/Linux, every environment (the step does not apply on the platform, so
# the row names the platform, not the environment: write_environment_skip is not used).
# Install source and platform status: the /tool-registry skill, entry "pywinpty"
# (macOS n/a, Linux n/a, Windows supported).
#
# Usage: setup-pywinpty.sh [--dry-run]   (AITOOLS_DRY_RUN=1 is the same; no other effect)

set -euo pipefail

# --- Flag parsing ---
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
    esac
done
[ "${AITOOLS_DRY_RUN:-}" = "1" ] && DRY_RUN=true

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-pywinpty"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- nothing to install on this platform"

log "n/a on $AITOOLS_PLATFORM: pywinpty is Windows-only; the pty test runner uses the stdlib pty module here; nothing changed"
write_summary OK "pywinpty" "n/a ($AITOOLS_PLATFORM)"

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
