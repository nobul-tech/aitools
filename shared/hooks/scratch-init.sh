#!/usr/bin/env bash
# scratch-init.sh — Claude Code SessionStart hook
# Creates a unique session scratch directory, logs stale dirs, discovers
# unconsumed handoffs, and registers the session in the harness SQLite DB.
#
# Design decisions:
#   - Silent exit on errors (hook must never break Claude Code)
#   - Logs stale session dirs older than 24h (no auto-delete after 30-file loss)
#   - Writes session dir path to .scratch/.current-session for agents
#   - Uses session_id from CC hook input for deterministic dir names (R1, #53)
#   - Discovers handoffs at .aitools/channel/handoffs/ (R3, #53)
#   - Registers session in harness SQLite DB if harness-db.py is available
#   - SQLite integration is OBSERVE mode (log-only, never blocks)
#   - harness-db.py stderr is NOT suppressed — safety warnings must surface

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

# Read hook input from stdin (contains session_id, cwd, etc.)
INPUT=$(cat)
SESSION_ID=$(json_field "$INPUT" "session_id")

# Find project root (hooks run in cwd but we need the git root)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(pwd)"
fi

SCRATCH_DIR="$PROJECT_ROOT/.scratch"

# Ensure .scratch/ exists
mkdir -p "$SCRATCH_DIR"

# --- Log stale session dirs (older than 24h) ---
# These are from crashed or killed sessions where SessionEnd never fired.
# Previously rm -rf'd here, but that destroyed 30 unharvested artifacts
# (session Z1IhGrcgGO, 2026-03-21). Now we leave them for manual cleanup.
if [ -d "$SCRATCH_DIR" ]; then
    stale_count=$(find "$SCRATCH_DIR" -maxdepth 1 -name "session-*" -type d -mmin +1440 2>/dev/null | wc -l | tr -d ' ')
    if [ "$stale_count" -gt 0 ]; then
        printf 'Stale scratch dirs: %d (older than 24h, run cleanup manually)\n' "$stale_count"
    fi
fi

# --- Create fresh session dir ---
# Use session_id for deterministic dir name (fixes .current-session race
# condition for concurrent sessions — M4 AAR P3, verified UA-6).
# Fallback to mktemp if session_id is empty (defensive).
SESSION_PREFIX=""
if [ -n "$SESSION_ID" ]; then
    SESSION_PREFIX=$(printf '%s' "$SESSION_ID" | cut -c1-10)
    SESSION_DIR="$SCRATCH_DIR/session-$SESSION_PREFIX"
    mkdir -p "$SESSION_DIR"
else
    SESSION_DIR=$(mktemp -d "$SCRATCH_DIR/session-XXXXXXXXXX")
fi

# Write the path so agents and the SessionEnd hook can find it
printf '%s' "$SESSION_DIR" > "$SCRATCH_DIR/.current-session"

# --- Discover unconsumed handoffs (R3, issue #53) ---
HANDOFFS_DIR="$PROJECT_ROOT/.aitools/channel/handoffs"
if [ -d "$HANDOFFS_DIR" ]; then
    handoff_count=0
    latest_handoff=""
    for hf in "$HANDOFFS_DIR"/handoff*; do
        [ -f "$hf" ] || continue
        handoff_count=$((handoff_count + 1))
        latest_handoff="$hf"
    done
    if [ "$handoff_count" -gt 0 ]; then
        printf 'Handoff available: %s (%d total in %s)\n' \
            "$(basename "$latest_handoff")" "$handoff_count" "$HANDOFFS_DIR"
    fi
fi

# --- Register session in harness SQLite DB (OBSERVE mode) ---
# This is additive — if harness-db.py is missing or fails, session
# continues normally. SQLite integration never blocks SessionStart.
if [ -n "$SESSION_ID" ]; then
    PYTHON=""
    if command -v python3 > /dev/null 2>&1; then
        PYTHON="python3"
    elif command -v python > /dev/null 2>&1; then
        PYTHON="python"
    fi

    if [ -n "$PYTHON" ]; then
        # Look for harness-db.py in multiple locations
        HELPER=""
        if [ -f "$PROJECT_ROOT/scripts/harness-db.py" ]; then
            HELPER="$PROJECT_ROOT/scripts/harness-db.py"
        elif [ -f "$HOME/repos/aitools/scripts/harness-db.py" ]; then
            HELPER="$HOME/repos/aitools/scripts/harness-db.py"
        fi

        if [ -n "$HELPER" ] && "$PYTHON" -c "import sqlite3" 2>/dev/null; then
            # Initialize harness databases (creates if missing)
            # Let stderr through (warnings visible to Claude), but don't block on failure
            "$PYTHON" "$HELPER" init || true
            # Register this session
            "$PYTHON" "$HELPER" session start --id "$SESSION_ID" || true
            printf 'Harness DB: session %s registered\n' "$SESSION_ID"
        fi
    fi
fi

# SessionStart stdout is added as context for Claude
printf 'Session scratch directory: %s\n' "$SESSION_DIR"
