#!/usr/bin/env bash
# harvest-session.sh -- Claude Code SessionEnd hook (thin shim)
# Passes the raw hook stdin to ait-harvest.py `harvest`, which classifies the
# session scratch dir, routes handoffs, harvests artifacts to harvesting/,
# updates the manifest, and prunes -- all in stdlib Python (no node).
# Logging lives in ~/.aitools/logs/ait-harvest.log.
#
# Design (plan imperative-gliding-newell.md §4 + §20.2 C3):
#   - Standalone (no aitools-lib); bash-only on all platforms.
#   - Raw stdin -> python (no bash JSON parsing).
#   - Always exit 0 (a hook must never break Claude Code).
#   - Bash-fallback log on no-Python / no-helper / non-zero exit.
#   - DB session-end marking is NOT done here -- harness-db-sessionend.sh owns
#     that (de-dups the overlap the old harvest hook had).
#   - 30-file-loss guards preserved inside the helper (never deletes scratch
#     dirs; marks 'pruned', never unlinks).

set -euo pipefail

INPUT=$(cat)

_fallback_log() {
    local logdir="${HOME:-}/.aitools/logs"
    local logfile="$logdir/harvest-session.log"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
    if mkdir -p "$logdir" 2>/dev/null; then
        printf '[%s] [harvest-session] [%s] %s\n' "$ts" "${2:-warn}" "$1" \
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
    _fallback_log "no Python on PATH; scratch not harvested" "warn"
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
    _fallback_log "ait-harvest.py not found; scratch not harvested" "warn"
    exit 0
fi

if ! printf '%s' "$INPUT" | "$PYTHON" "$HELPER" harvest; then
    _fallback_log "ait-harvest.py harvest exited non-zero" "warn"
fi

exit 0
