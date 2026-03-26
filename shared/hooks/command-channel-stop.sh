#!/usr/bin/env bash
# command-channel-stop.sh -- Claude Code Stop hook
# Purpose: Poll the session SQLite DB for pending commander directives and
#   inject them into the agent's context via stderr. This is the "uplink"
#   path of the command channel -- dashboard writes directives to SQLite,
#   this hook reads them at every agent pause.
# Scope: Stop hook only. NOT the directive schema (harness-db.py).
#   NOT the dashboard command interface (session-command-center-v2.py).
# Audience: Claude Code Stop hook system -- fires after every agent response.
#
# Architecture (from command-channel-investigation.md):
#   Layer 1 -- Stop-hook command reader (THIS FILE)
#   Layer 2 -- Command protocol (commander_directives table in session DB)
#   Layer 3 -- Dashboard command interface (session-command-center-v2.py)
#
# Hook contract:
#   - Receives JSON on stdin (session_id, cwd, transcript_summary, etc.)
#   - Exit 0 = no-op (no pending directives)
#   - Exit 2 = block (stderr injected as context, forces agent to address)
#   - Must complete in <50ms (SQLite WAL read)
#   - Must never crash or hang (would break Claude Code)
#
# Priority handling:
#   - flash:    exit 2 (block) -- agent must address immediately
#   - priority: exit 2 (block) -- surfaced with emphasis
#   - normal:   exit 2 (block) -- agent should address when convenient
#   All pending directives are surfaced together. Flash/priority directives
#   get prefixes in the stderr output.
#
# Fallback: also checks commander_feedback table (from dashboard v2)
#   for status='submitted' entries, since both tables serve the same
#   purpose. commander_directives is the canonical table going forward.
#
# Platform: macOS + Linux + Windows Git Bash
# Dependencies: Python 3 with sqlite3 stdlib (same as harness-db hooks)

set -euo pipefail

# --- Read hook input from stdin ---
INPUT=$(cat)

# --- Pure-bash JSON field extraction (same pattern as other hooks) ---
json_field() {
    local json="$1" key="$2"
    local pattern="\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
    if [[ "$json" =~ $pattern ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

SESSION_ID=$(json_field "$INPUT" "session_id")

# Bail if no session ID
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# --- Find session DB path ---
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
    exit 0
fi

SESSION_PREFIX="${SESSION_ID:0:10}"
SESSION_DB="$PROJECT_ROOT/.aitools/sessions/${SESSION_PREFIX}.db"

if [ ! -f "$SESSION_DB" ]; then
    exit 0
fi

# --- Check for Python 3 ---
PYTHON=""
if command -v python3 > /dev/null 2>&1; then
    PYTHON="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON="python"
fi

if [ -z "$PYTHON" ]; then
    exit 0
fi

# --- Poll for pending directives via inline Python ---
# Python writes directive text to stderr (injected into agent context by CC).
# Python prints the directive count to stdout (captured by bash for exit code).
# Single invocation for speed (<50ms with SQLite WAL).
DIRECTIVE_COUNT=$("$PYTHON" - "$SESSION_DB" <<'PYEOF'
import sqlite3
import sys
from datetime import datetime, timezone

db_path = sys.argv[1]

def utcnow():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

try:
    conn = sqlite3.connect(f"file:{db_path}?mode=rw", uri=True, timeout=2.0)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA busy_timeout=2000")
    conn.row_factory = sqlite3.Row
except Exception:
    print("0")
    sys.exit(0)

pending = []
now = utcnow()

# Check commander_directives table (Layer 2 protocol)
try:
    rows = conn.execute(
        "SELECT directive_id, directive_type, priority, message, target "
        "FROM commander_directives WHERE status = 'pending' ORDER BY created_at"
    ).fetchall()
    for r in rows:
        priority = r["priority"]
        prefix = "[FLASH] " if priority == "flash" else "[PRIORITY] " if priority == "priority" else ""
        dtype = r["directive_type"].upper()
        msg = r["message"]
        target = f" (re: {r['target']})" if r["target"] else ""
        pending.append(f"{prefix}{dtype}{target}: {msg}")
        conn.execute(
            "UPDATE commander_directives SET status = 'acknowledged', acknowledged_at = ? WHERE directive_id = ?",
            (now, r["directive_id"]),
        )
except Exception:
    pass  # table may not exist yet -- that's OK

# Check commander_feedback table (dashboard v2 fallback)
try:
    rows = conn.execute(
        "SELECT feedback_id, feedback_type, message, target "
        "FROM commander_feedback WHERE status = 'submitted' ORDER BY created_at"
    ).fetchall()
    for r in rows:
        ftype = r["feedback_type"].upper()
        msg = r["message"]
        target = f" (re: {r['target']})" if r["target"] else ""
        pending.append(f"{ftype}{target}: {msg}")
        conn.execute(
            "UPDATE commander_feedback SET status = 'acknowledged', acknowledged_at = ? WHERE feedback_id = ?",
            (now, r["feedback_id"]),
        )
except Exception:
    pass  # table may not exist yet -- that's OK

if pending:
    conn.commit()
    print("=== COMMANDER DIRECTIVE(S) ===", file=sys.stderr)
    for p in pending:
        print(f"  {p}", file=sys.stderr)
    print("=== END DIRECTIVES -- Address these before continuing ===", file=sys.stderr)

conn.close()
print(len(pending))
PYEOF
) || DIRECTIVE_COUNT="0"

# Guard: ensure DIRECTIVE_COUNT is a valid number
if ! [[ "$DIRECTIVE_COUNT" =~ ^[0-9]+$ ]]; then
    DIRECTIVE_COUNT="0"
fi

# --- Telemetry: JSONL event emission ---
_SESSION_DIR=""
_cs_file="$PROJECT_ROOT/.scratch/.current-session"
if [ -f "$_cs_file" ]; then
    _SESSION_DIR=$(cat "$_cs_file" 2>/dev/null || true)
fi

if [ -n "$_SESSION_DIR" ] && [ "$DIRECTIVE_COUNT" != "0" ]; then
    printf '{"t":"%s","type":"command_channel","src":"ccs","d":{"count":%s}}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$DIRECTIVE_COUNT" \
        >> "$_SESSION_DIR/events.jsonl" 2>/dev/null || true
fi

# --- Exit code ---
# If any directives were found and injected via stderr, block (exit 2)
# to force the agent to address them before continuing.
if [ "$DIRECTIVE_COUNT" != "0" ]; then
    exit 2
fi

exit 0
