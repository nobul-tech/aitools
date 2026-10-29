#!/usr/bin/env bash
# harness-db-sessionstart.sh -- Claude Code SessionStart hook
# Initializes harness databases and registers the current session.
#
# Design decisions:
#   - Requires Python 3 (sqlite3 stdlib -- no external deps)
#   - Creates harness DB + session DB via harness-db.py helper
#   - Silent exit on missing deps (hook must never break Claude Code)
#   - Output channel: SessionStart plain stdout is added to Claude's
#     context; stderr of a hook that exits 0 never reaches Claude (Claude
#     Code hooks reference, "Exit code 0"). So harness-db.py runs with
#     2>&1: its warnings and errors land on stdout, where Claude reads them
#     (harness-db.py itself logs detail to ~/.aitools/logs/harness-db.log).
#   - The status line is honest: "registered" only when both harness-db.py
#     calls exited 0, otherwise "NOT registered" with the failed step.
#   - Cross-platform: Python sqlite3 works on macOS, Windows Git Bash, Linux
#   - Session ID from CC hook input (same pattern as scratch-init.sh)
# Platform: macOS + Linux + Windows Git Bash (bash 3.2 compatible)

set -euo pipefail

# --- Pure-bash JSON field extraction (same as scratch-init.sh) ---
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

# Read hook input from stdin (contains session_id, cwd, etc.)
INPUT=$(cat)
SESSION_ID=$(json_field "$INPUT" "session_id")

# Bail if no session ID (defensive)
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# Find project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(pwd)"
fi

# Check for Python 3 (required for harness-db.py)
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi

if [ -z "$PYTHON" ]; then
    printf 'harness-db: Python 3 not found, skipping DB init\n'
    exit 0
fi

# Verify sqlite3 module is available
if ! "$PYTHON" -c "import sqlite3" 2>/dev/null; then
    printf 'harness-db: Python sqlite3 module not available, skipping DB init\n'
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

# Initialize harness databases (creates if missing).
# 2>&1: warnings reach Claude on stdout (see header). A failure never
# blocks the session; it is reported on the status line below.
hdb_failed=""
if ! PYTHONUNBUFFERED=1 "$PYTHON" "$HELPER" init 2>&1; then
    hdb_failed="init"
fi

# Register this session (pass the resolved project root so it is recorded
# in the session table — avoids delegations hardcoding per-machine paths)
if ! PYTHONUNBUFFERED=1 "$PYTHON" "$HELPER" session start --id "$SESSION_ID" --project-dir "$PROJECT_ROOT" 2>&1; then
    hdb_failed="${hdb_failed:+$hdb_failed, }session start"
fi

if [ -z "$hdb_failed" ]; then
    printf 'Harness DB: session %s registered\n' "$SESSION_ID"
else
    printf 'Harness DB: session %s NOT registered (harness-db.py %s failed; the cause is in the harness-db.py output above)\n' "$SESSION_ID" "$hdb_failed"
fi

SHORT_ID="${SESSION_ID:0:10}"
printf 'This is Session Commander %s.\n' "$SHORT_ID"
