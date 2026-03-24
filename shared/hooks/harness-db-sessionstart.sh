#!/usr/bin/env bash
# harness-db-sessionstart.sh -- Claude Code SessionStart hook
# Initializes harness databases and registers the current session.
#
# Design decisions:
#   - Requires Python 3 (sqlite3 stdlib -- no external deps)
#   - Creates harness DB + session DB via harness-db.py helper
#   - Silent exit on errors (hook must never break Claude Code)
#   - Cross-platform: Python sqlite3 works on macOS, Windows Git Bash, Linux
#   - Session ID from CC hook input (same pattern as scratch-init.sh)

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

HELPER="$PROJECT_ROOT/scripts/harness-db.py"

# Check helper script exists
if [ ! -f "$HELPER" ]; then
    exit 0
fi

# Initialize harness databases (creates if missing)
"$PYTHON" "$HELPER" init 2>/dev/null || true

# Register this session
"$PYTHON" "$HELPER" session start --id "$SESSION_ID" 2>/dev/null || true

printf 'Harness DB: session %s registered\n' "$SESSION_ID"
