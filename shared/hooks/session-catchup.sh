#!/usr/bin/env bash
# session-catchup.sh -- Claude Code SessionStart hook (thin shim)
# Recovers carry-forward that SessionEnd missed (abrupt exit / sleep / offline):
# archives orphaned CC transcripts globally and harvests orphaned scratch dirs.
# All logic, the single-flight lock, and logging live in ait-harvest.py
# (~/.aitools/logs/ait-harvest.log).
#
# Design (plan imperative-gliding-newell.md §4 + §16 + §20.1/§20.2):
#   - Standalone (no aitools-lib); bash-only on all platforms.
#   - Raw stdin -> python `catchup` (the helper reads session_id + cwd, and
#     skips its OWN session via the stdin session_id -- deterministic, never DB).
#   - Synchronous with a ~10s graceful deadline (in-Python; timeout(1) is not
#     portable). Single-flight: skips its sweep if another session holds the lock.
#   - Always exit 0; bash-fallback log on no-Python / no-helper / non-zero exit.

set -euo pipefail

INPUT=$(cat)

_fallback_log() {
    local logdir="${HOME:-}/.aitools/logs"
    local logfile="$logdir/session-catchup.log"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
    if mkdir -p "$logdir" 2>/dev/null; then
        printf '[%s] [session-catchup] [%s] %s\n' "$ts" "${2:-warn}" "$1" \
            >> "$logfile" 2>/dev/null || true
    fi
}

PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi

if [ -z "$PYTHON" ]; then
    _fallback_log "no Python on PATH; catchup skipped" "warn"
    exit 0
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
HELPER=""
if [ -n "$PROJECT_ROOT" ] && [ -f "$PROJECT_ROOT/scripts/ait-harvest.py" ]; then
    HELPER="$PROJECT_ROOT/scripts/ait-harvest.py"
elif [ -f "$HOME/.claude/hooks/ait-harvest.py" ]; then
    HELPER="$HOME/.claude/hooks/ait-harvest.py"
elif [ -f "$HOME/repos/aitools/scripts/ait-harvest.py" ]; then
    HELPER="$HOME/repos/aitools/scripts/ait-harvest.py"
fi

if [ -z "$HELPER" ]; then
    _fallback_log "ait-harvest.py not found; catchup skipped" "warn"
    exit 0
fi

if ! printf '%s' "$INPUT" | "$PYTHON" "$HELPER" catchup --deadline 10; then
    _fallback_log "ait-harvest.py catchup exited non-zero" "warn"
fi

exit 0
