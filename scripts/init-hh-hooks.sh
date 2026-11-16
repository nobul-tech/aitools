#!/usr/bin/env bash
# One-time: point this repo at scripts/githooks (honest harness pre-commit).
# Run from aitools repo root: bash scripts/init-hh-hooks.sh
# Platform: macOS/Linux (OS guard below). On Windows, run the git command
# itself: git config core.hooksPath scripts/githooks

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/aitools-lib.sh
source "$ROOT/scripts/aitools-lib.sh"
# shellcheck source=scripts/init-logging.sh
source "$ROOT/scripts/init-logging.sh"

# OS guard (.claude/rules/cross-platform.md "OS guard patterns"; commander,
# 2026-11-14, on the entry points that never run on Windows: "add an OS guard
# to all of them")
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, run: git config core.hooksPath scripts/githooks"
        exit 1 ;;
esac

cd "$ROOT"
# Captured, so a failure is reported with git's own message (reference/logging.md
# 8.3); an empty TOOL records it under this script's name (8.2)
GIT_RC=0
GIT_OUT=$(git config core.hooksPath scripts/githooks 2>&1) || GIT_RC=$?
if [ "$GIT_RC" -ne 0 ]; then
    write_error "" "git config core.hooksPath failed" "$(error_reason "$GIT_OUT" "$GIT_RC")"
    exit 1
fi
log_ok "core.hooksPath = scripts/githooks (pre-commit regenerates deploy/ when shared/ changes)"
log "Disable: git config --unset core.hooksPath"
