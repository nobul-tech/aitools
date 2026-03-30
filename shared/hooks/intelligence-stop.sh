#!/usr/bin/env bash
# intelligence-stop.sh -- Claude Code Stop hook (intelligence carry-forward)
# Purpose: Bash wrapper that detects Python 3 and invokes intelligence-stop.py.
#
# Hook contract:
#   - Receives JSON on stdin (session_id, transcript_path, cwd)
#   - Passes stdin through to the Python script
#   - Forwards exit code from Python (0 = allow, 2 = block with stderr)
#   - Exits 0 on any infrastructure error (missing Python, missing .py file)
#
# Provenance: Session f5fa32f9-c (2026-03-29). Intelligence pillar Stop hook.
# Platform: macOS + Linux + Windows Git Bash

set -euo pipefail

# --- Read hook input from stdin (must capture before pipe) ---
INPUT=$(cat)

# --- Detect Python 3 ---
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi

if [ -z "$PYTHON" ]; then
    exit 0
fi

# Verify sqlite3 module
if ! "$PYTHON" -c "import sqlite3" 2>/dev/null; then
    exit 0
fi

# --- Locate the Python hook script ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_HOOK="$SCRIPT_DIR/intelligence-stop.py"

if [ ! -f "$PY_HOOK" ]; then
    PY_HOOK="$HOME/.claude/hooks/intelligence-stop.py"
fi

if [ ! -f "$PY_HOOK" ]; then
    exit 0
fi

# --- Invoke Python hook ---
printf '%s' "$INPUT" | "$PYTHON" "$PY_HOOK"
exit $?
