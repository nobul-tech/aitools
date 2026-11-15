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
git config core.hooksPath scripts/githooks
echo "core.hooksPath = scripts/githooks (pre-commit regenerates deploy/ when shared/ changes)"
echo "Disable: git config --unset core.hooksPath"
