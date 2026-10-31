#!/usr/bin/env bash
# a123b-step45.sh -- audit driver: run steps 4 and 5 of setup-user-cursor.sh
# (text from 'log "Step 4: Cursor user rules"' to the "END cursor body"
# marker, unmodified) plus the script's own exit footer, the bash twin of
# tests/rules-fanout-cursor/step4-driver.ps1. Steps 1-3 never run.
# Usage: bash a123b-step45.sh <setup-user-cursor.sh> [--dry-run] [--force]
# Run under an isolated HOME only.
set -euo pipefail
SCRIPT="${1:?usage: a123b-step45.sh SCRIPT [--dry-run]}"
shift
DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
    esac
done
[ "${AITOOLS_DRY_RUN:-}" = "1" ] && DRY_RUN=true
case "$HOME" in /Users/new-jose) echo "refusing: real HOME" >&2; exit 9 ;; esac
source "$(cd "$(dirname "$SCRIPT")" && pwd)/aitools-lib.sh"
logging_init "setup-user-cursor"
CURSOR_DIR="$HOME/.cursor"
BODY=$(perl -ne '$p = 1 if /^log "Step 4: Cursor user rules"/; last if /^# --- END cursor body/; print if $p' "$SCRIPT")
FOOTER=$(perl -ne '$p = 1 if /^# --- BEGIN exit/; print if $p; last if /^# --- END exit/' "$SCRIPT")
if [ -z "$BODY" ] || [ -z "$FOOTER" ]; then echo "step 4/5 or footer not found" >&2; exit 9; fi
eval "$BODY"
eval "$FOOTER"
