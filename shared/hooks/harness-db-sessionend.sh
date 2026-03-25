#!/usr/bin/env bash
# harness-db-sessionend.sh -- Claude Code SessionEnd hook
# Marks the current session as complete and exports DB to JSON for
# git carry-forward (Option B: SQLite runtime, JSON archive).
#
# Design decisions:
#   - Requires Python 3 (sqlite3 stdlib -- no external deps)
#   - Exports session DB to .aitools/channel/running-estimate.json (tracked)
#   - Silent exit on missing deps (hook must never break Claude Code)
#   - harness-db.py stderr is NOT suppressed — safety warnings must surface
#   - Cross-platform: Python sqlite3 works on macOS, Windows Git Bash, Linux
#   - Session ID from CC hook input (same pattern as harvest-session.sh)

set -euo pipefail

# --- Pure-bash JSON field extraction (same as harvest-session.sh) ---
json_field() {
    local json="$1" key="$2"
    local val
    val=$(printf '%s' "$json" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"//' \
        | sed 's/"$//')
    printf '%s' "$val"
}

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(json_field "$INPUT" "session_id")

# Bail if no session ID (defensive)
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# Find project root
CWD=$(json_field "$INPUT" "cwd")
if [ -n "$CWD" ]; then
    PROJECT_ROOT=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")
else
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")
fi

# Check for Python 3
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi

if [ -z "$PYTHON" ]; then
    exit 0
fi

HELPER="$PROJECT_ROOT/scripts/harness-db.py"

# Check helper script exists
if [ ! -f "$HELPER" ]; then
    exit 0
fi

# Mark session as ended
# Let stderr through (warnings visible to Claude), but don't block on failure
"$PYTHON" "$HELPER" session end --id "$SESSION_ID" || true

# Process session events.jsonl into KPI metrics (cold-path telemetry)
# Reads events emitted by enforcement hooks during the session
"$PYTHON" "$HELPER" process-events --session "$SESSION_ID" || true

# Ship KPI events to Datadog (if DD_API_KEY is configured)
"$PYTHON" "$HELPER" ship || true

# Export DB to JSON for git carry-forward
# stderr warnings (e.g. overwrite-smaller-file safety check) must be visible
"$PYTHON" "$HELPER" export --format json --session "$SESSION_ID" || true

printf 'Harness DB: session %s ended, events processed, JSON exported\n' "$SESSION_ID"
