#!/usr/bin/env bash
# harness-db-sessionend.sh -- Claude Code SessionEnd hook
# Marks the current session as complete and exports DB to JSON for
# git carry-forward (Option B: SQLite runtime, JSON archive).
#
# Design decisions:
#   - Requires Python 3 (sqlite3 stdlib -- no external deps)
#   - Exports session DB to .aitools/channel/running-estimate.json (tracked)
#   - Silent exit on missing deps (hook must never break Claude Code)
#   - Output channel: nothing this hook prints reaches Claude. SessionEnd
#     discards JSON output and shows stderr to the user at most (Claude Code
#     hooks reference, "Exit code 2 behavior per event" and "SessionEnd");
#     the session is ending, so there is no next turn. harness-db.py logs
#     its warnings (e.g. the overwrite-smaller-file export check) to
#     ~/.aitools/logs/harness-db.log, which is where to look for them.
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

# Resolve harness-db.py: prefer the deployed copy (~/.aitools/bin) so it
# works in every project; fall back to the repo for dev in aitools itself.
HELPER=""
for _cand in "$HOME/.aitools/bin/harness-db.py" "$PROJECT_ROOT/scripts/harness-db.py" "$HOME/repos/aitools/scripts/harness-db.py"; do
    if [ -f "$_cand" ]; then HELPER="$_cand"; break; fi
done

# Check helper script exists
if [ -z "$HELPER" ]; then
    exit 0
fi

# Mark session as ended
# stderr is left to the user's terminal (see header); never blocks session end
"$PYTHON" "$HELPER" session end --id "$SESSION_ID" || true

# Process session events.jsonl into KPI metrics (cold-path telemetry)
# Reads events emitted by enforcement hooks during the session
"$PYTHON" "$HELPER" process-events --session "$SESSION_ID" || true

# Ship KPI events to Datadog (if DD_API_KEY is configured)
"$PYTHON" "$HELPER" ship || true

# Export DB to JSON for git carry-forward
# The overwrite-smaller-file safety check logs to ~/.aitools/logs/harness-db.log
"$PYTHON" "$HELPER" export --format json --session "$SESSION_ID" || true

printf 'Harness DB: session %s ended, events processed, JSON exported\n' "$SESSION_ID"
