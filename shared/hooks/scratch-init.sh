#!/usr/bin/env bash
# scratch-init.sh — Claude Code SessionStart hook
# Creates a unique session scratch directory and cleans up stale dirs.
#
# Design decisions:
#   - Silent exit on errors (hook must never break Claude Code)
#   - Cleans up session dirs older than 24h (crashed/killed sessions)
#   - Writes session dir path to .scratch/.current-session for agents
#   - Uses mktemp for uniqueness, no collision risk

set -euo pipefail

# Read hook input from stdin (contains session_id, cwd, etc.)
INPUT=$(cat)

# Find project root (hooks run in cwd but we need the git root)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(pwd)"
fi

SCRATCH_DIR="$PROJECT_ROOT/.scratch"

# Ensure .scratch/ exists
mkdir -p "$SCRATCH_DIR"

# --- Clean up stale session dirs (older than 24h) ---
# These are from crashed or killed sessions where SessionEnd never fired
if [ -d "$SCRATCH_DIR" ]; then
    find "$SCRATCH_DIR" -maxdepth 1 -name "session-*" -type d -mmin +1440 2>/dev/null \
        | while IFS= read -r stale_dir; do
            rm -rf "$stale_dir"
        done
fi

# --- Create fresh session dir ---
SESSION_DIR=$(mktemp -d "$SCRATCH_DIR/session-XXXXXXXXXX")

# Write the path so agents and the SessionEnd hook can find it
printf '%s' "$SESSION_DIR" > "$SCRATCH_DIR/.current-session"

# SessionStart stdout is added as context for Claude
printf 'Session scratch directory: %s\n' "$SESSION_DIR"
