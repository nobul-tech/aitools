#!/usr/bin/env bash
# session-archive.sh -- Claude Code SessionEnd hook (thin shim)
# Passes the raw hook stdin to ait-harvest.py `archive`, which copies the
# transcript (+ subagents) to the dotprofile and commits/pushes. All logic and
# logging live in the Python helper (~/.aitools/logs/ait-harvest.log).
#
# Design (plan imperative-gliding-newell.md §4 + §20.2 C3):
#   - Standalone (no aitools-lib); bash-only on all platforms.
#   - Raw stdin -> python (no bash JSON parsing; the helper parses robustly).
#   - Always exit 0 (a hook must never break Claude Code).
#   - If Python / the helper is missing or the helper exits non-zero, append a
#     one-line reason to ~/.aitools/logs/session-archive.log FROM BASH -- because
#     Python may be the missing thing, or may die before its logging initializes.
#
# Baseline: Claude Code 2.1.51 hook schema (session_id, cwd, transcript_path).

set -euo pipefail

INPUT=$(cat)

# Bash-only fallback logger for the pre-Python / no-Python branches (§20.2 C3).
# Never fails the hook: if even logging is impossible, we still exit 0.
_fallback_log() {
    local logdir="${HOME:-}/.aitools/logs"
    local logfile="$logdir/session-archive.log"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
    # mkdir + append may fail if HOME unset / dir unwritable; that is acceptable
    # for a logging fallback -- the hook must not crash. Result is checked by the
    # || true and the surrounding exit 0.
    if mkdir -p "$logdir" 2>/dev/null; then
        printf '[%s] [session-archive] [%s] %s\n' "$ts" "${2:-warn}" "$1" \
            >> "$logfile" 2>/dev/null || true
    fi
}

# Resolve Python (existence check with explicit fallback -- error-handling rule 5).
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi

if [ -z "$PYTHON" ]; then
    _fallback_log "no Python on PATH; transcript not archived" "warn"
    exit 0
fi

# Resolve the helper (project root, then the canonical clone).
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
    _fallback_log "ait-harvest.py not found; transcript not archived" "warn"
    exit 0
fi

# Pass raw stdin; let stderr through (warnings visible). Never block.
if ! printf '%s' "$INPUT" | "$PYTHON" "$HELPER" archive; then
    _fallback_log "ait-harvest.py archive exited non-zero" "warn"
fi

exit 0
