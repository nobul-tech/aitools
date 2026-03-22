#!/usr/bin/env bash
# scratch-init.sh — Claude Code SessionStart hook
# Creates a unique session scratch directory and logs stale dirs.
#
# Design decisions:
#   - Silent exit on errors (hook must never break Claude Code)
#   - Logs stale session dirs older than 24h (no auto-delete after 30-file loss)
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
SESSION_DIR=$(mktemp -d "$SCRATCH_DIR/session-XXXXXXXXXX")

# Write the path so agents and the SessionEnd hook can find it
printf '%s' "$SESSION_DIR" > "$SCRATCH_DIR/.current-session"

# SessionStart stdout is added as context for Claude
printf 'Session scratch directory: %s\n' "$SESSION_DIR"
