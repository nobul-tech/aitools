#!/usr/bin/env bash
# session-archive.sh — Claude Code SessionEnd hook
# Archives session transcript to user repo after each session ends.
#
# Baseline: Claude Code 2.1.51 -- hook schema (session_id, cwd, transcript_path)
# Hook input: JSON on stdin with session_id, cwd, transcript_path, etc.
# See reference/user-repo.md for the archiving pattern.
#
# Design decisions:
#   - Silent exit on any misconfiguration (hook must never break Claude Code)
#   - No git operations (user commits/pushes on their own schedule)
#   - Pure-bash JSON parsing (jq not guaranteed in hook environment)
#   - Uses transcript file birth time for date (session start), fallback to today

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# --- Pure-bash JSON field extraction ---
# Extracts a top-level string value from JSON. Handles simple cases only.
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

SESSION_ID=$(json_field "$INPUT" "session_id")
CWD=$(json_field "$INPUT" "cwd")
TRANSCRIPT=$(json_field "$INPUT" "transcript_path")

# All three fields are required
if [ -z "$SESSION_ID" ] || [ -z "$CWD" ] || [ -z "$TRANSCRIPT" ]; then
    exit 0
fi

# Transcript file must exist
if [ ! -f "$TRANSCRIPT" ]; then
    exit 0
fi

# --- Read user repo path from aitools config ---
CONFIG_FILE="${HOME}/.aitools/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0  # aitools not configured
fi

USER_REPO=$(json_field "$(cat "$CONFIG_FILE")" "userRepoPath")

if [ -z "$USER_REPO" ] || [ ! -d "$USER_REPO" ]; then
    exit 0  # user repo not configured or missing
fi

# --- Derive project name ---
REPO_ROOT=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$REPO_ROOT" ]; then
    PROJECT=$(basename "$REPO_ROOT")
else
    PROJECT=$(basename "$CWD" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9-]/-/g')
fi

# --- Derive date from transcript file creation time ---
if [ "$(uname -s)" = "Darwin" ]; then
    DATE=$(stat -f "%SB" -t "%Y-%m-%d" "$TRANSCRIPT" 2>/dev/null || date -u +%Y-%m-%d)
else
    # Linux: stat -c %W gives birth time (0 if unsupported), fallback to modify time
    BIRTH=$(stat -c "%W" "$TRANSCRIPT" 2>/dev/null || echo "0")
    if [ "$BIRTH" != "0" ] && [ -n "$BIRTH" ]; then
        DATE=$(date -u -d "@$BIRTH" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)
    else
        DATE=$(date -u -d "@$(stat -c '%Y' "$TRANSCRIPT" 2>/dev/null)" +%Y-%m-%d 2>/dev/null || date -u +%Y-%m-%d)
    fi
fi

# --- Session ID prefix (first 8 chars) ---
PREFIX=$(printf '%s' "$SESSION_ID" | cut -c1-8)

# --- Target path ---
DEST_DIR="${USER_REPO}/sessions/${PROJECT}"
DEST_FILE="${DEST_DIR}/${DATE}_${PREFIX}.jsonl"

# Skip if already archived
if [ -f "$DEST_FILE" ]; then
    exit 0
fi

mkdir -p "$DEST_DIR"
cp "$TRANSCRIPT" "$DEST_FILE"

# --- Log archive event to harness DB (OBSERVE mode) ---
# Additive: if harness-db.py is missing or fails, archive still succeeds.
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi

if [ -n "$PYTHON" ] && [ -n "$REPO_ROOT" ]; then
    HELPER=""
    if [ -f "$REPO_ROOT/scripts/harness-db.py" ]; then
        HELPER="$REPO_ROOT/scripts/harness-db.py"
    elif [ -f "$HOME/repos/aitools/scripts/harness-db.py" ]; then
        HELPER="$HOME/repos/aitools/scripts/harness-db.py"
    fi

    if [ -n "$HELPER" ] && "$PYTHON" -c "import sqlite3" 2>/dev/null; then
        "$PYTHON" "$HELPER" log \
            --session "$SESSION_ID" \
            --type sitrep \
            --agent "session-archive" \
            --message "Transcript archived to ${DEST_FILE}" \
            2>/dev/null || true
    fi
fi
