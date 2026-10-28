#!/usr/bin/env bash
# test-hooks-smoke.sh -- smoke tests for the shared/hooks scripts whose output
# channel was audited (HOOK2-AUDIT, 2026-10-28) and left unchanged.
#
# Each hook gets a clean input (expected exit and output) and, where it has
# one, its guidance case, checked on the channel Claude Code reads:
#   standing-order-guard.sh   PreToolUse   exit 2 + stderr on a violation; exempt sed -n
#   block-claude-code-guide.sh PreToolUse  exit 0 + permissionDecision deny JSON
#   block-explore-agent.sh    PreToolUse   exit 0 + permissionDecision deny JSON
#   command-channel-stop.sh   Stop         exit 2 + stderr on a pending directive
#   intelligence-stop.sh      Stop         exit 2 + stderr on new intelligence
#   failure-mode-*-stop.sh    Stop         stubs: exit 0, no output
#   harness-db-sessionend.sh  SessionEnd   exit 0 even when the helper fails
#   tool-ops-session-audit.sh SessionEnd   exit 0, result to its JSONL log only
#   session-archive.sh, harvest-session.sh, session-catchup.sh: exit 0, no
#     output, fallback log line when ait-harvest.py is not found
# NOT run: dashboard-serve.sh (it starts the aitools CLI or a server).
# All hooks run with an isolated HOME and, unless a case needs a repo, a cwd
# that is not a git repo (no telemetry into a real session dir).
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run.
# Usage: bash tests/hooks/test-hooks-smoke.sh
#        AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-hooks-smoke.sh

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook-test-lib.sh"

P="$WORK/p.json"
SID="feedc0ffee-1111-2222-3333-444455556666"
PREFIX="feedc0ffee"

echo "== standing-order-guard.sh =="
H="$HOOKS/standing-order-guard.sh"
printf '{"tool_name":"Bash","tool_input":{"command":"git status"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "clean: exit 0, no output" quiet0
printf '{"tool_name":"Bash","tool_input":{"command":"git status && git log"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "&&: exit 2" [ "$RC" -eq 2 ]
check "&&: reason on stderr" contains "$ERR" "Don't use '&&'"
check "&&: no stdout" [ -z "$OUT" ]
printf '{"tool_name":"Bash","tool_input":{"command":"sed -n 1,5p file.txt"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "sed -n exemption: exit 0, no output" quiet0
printf '{"tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ file.txt"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "sed -i: exit 2" [ "$RC" -eq 2 ]

echo "== block-claude-code-guide.sh =="
H="$HOOKS/block-claude-code-guide.sh"
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide","prompt":"x"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "claude-code-guide: exit 0" [ "$RC" -eq 0 ]
check "claude-code-guide: valid PreToolUse JSON with a reason" ctx_has PreToolUse "DENIED"
check "claude-code-guide: permissionDecision deny" contains "$OUT" '"permissionDecision": "deny"'
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "general-purpose: exit 0, no output" quiet0

echo "== block-explore-agent.sh =="
H="$HOOKS/block-explore-agent.sh"
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore","prompt":"x"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "Explore: exit 0" [ "$RC" -eq 0 ]
check "Explore: valid PreToolUse JSON with a reason" ctx_has PreToolUse "general-purpose"
check "Explore: permissionDecision deny" contains "$OUT" '"permissionDecision": "deny"'
printf '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}' > "$P"
run_hook "$H" "$P" "$NOGIT"
check "general-purpose: exit 0, no output" quiet0

echo "== failure-mode stubs =="
for h in failure-mode-identity-stop.sh failure-mode-verify-stop.sh; do
    printf '{"session_id":"%s","hook_event_name":"Stop"}' "$SID" > "$P"
    run_hook "$HOOKS/$h" "$P" "$NOGIT"
    check "$h: exit 0, no output" quiet0
done

echo "== command-channel-stop.sh and intelligence-stop.sh =="
PROJ="$WORK/proj"
mkdir -p "$PROJ/.aitools/sessions"
git -C "$PROJ" init -q
# cwd as Claude Code sends it (native path): intelligence-stop.py resolves it
# with Python's os.path, which cannot open an MSYS /tmp/... path on Windows.
printf '{"session_id":"%s","cwd":"%s","transcript_path":"","hook_event_name":"Stop","stop_hook_active":false}' "$SID" "$(native_path "$PROJ")" > "$P"
run_hook "$HOOKS/command-channel-stop.sh" "$P" "$PROJ"
check "command-channel, no session DB: exit 0, no output" quiet0
run_hook "$HOOKS/intelligence-stop.sh" "$P" "$PROJ"
check "intelligence, no session DB: exit 0, no output" quiet0
if [ -n "$PYBIN" ]; then
    "$PYBIN" - "$PROJ/.aitools/sessions/$PREFIX.db" <<'PYEOF'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("CREATE TABLE commander_directives (directive_id INTEGER PRIMARY KEY, directive_type TEXT, priority TEXT, message TEXT, target TEXT, status TEXT, created_at TEXT, acknowledged_at TEXT)")
c.execute("INSERT INTO commander_directives (directive_type, priority, message, target, status, created_at) VALUES ('order', 'flash', 'stop and report', NULL, 'pending', '2026-10-28T00:00:00Z')")
c.execute("CREATE TABLE observations (observation_id INTEGER PRIMARY KEY, category TEXT, text TEXT, created_at TEXT)")
c.execute("INSERT INTO observations (category, text, created_at) VALUES ('OL', 'smoke observation', '2026-10-28T00:00:00Z')")
c.commit()
PYEOF
    run_hook "$HOOKS/command-channel-stop.sh" "$P" "$PROJ"
    check "command-channel, pending directive: exit 2" [ "$RC" -eq 2 ]
    check "command-channel: directive on stderr" contains "$ERR" "[FLASH] ORDER: stop and report"
    check "command-channel: no stdout" [ -z "$OUT" ]
    run_hook "$HOOKS/command-channel-stop.sh" "$P" "$PROJ"
    check "command-channel, acknowledged: exit 0, no output" quiet0
    run_hook "$HOOKS/intelligence-stop.sh" "$P" "$PROJ"
    check "intelligence, new observation: exit 2" [ "$RC" -eq 2 ]
    check "intelligence: [INTEL] block on stderr" contains "$ERR" "smoke observation"
    check "intelligence: no stdout" [ -z "$OUT" ]
else
    skip "Stop hooks with a session DB (no python with sqlite3)"
fi

echo "== harness-db-sessionend.sh =="
H="$HOOKS/harness-db-sessionend.sh"
printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionEnd","reason":"other"}' "$SID" "$NOGIT" > "$P"
run_hook "$H" "$P" "$NOGIT"
check "no helper: exit 0, no output" quiet0
if [ -n "$PYBIN" ]; then
    mkdir -p "$TEST_HOME/.aitools/bin"
    printf 'import sys\nsys.stderr.write("helper failed\\n")\nsys.exit(1)\n' > "$TEST_HOME/.aitools/bin/harness-db.py"
    run_hook "$H" "$P" "$NOGIT"
    check "helper fails: exit 0 (never blocks session end)" [ "$RC" -eq 0 ]
    rm -f "$TEST_HOME/.aitools/bin/harness-db.py"
fi

echo "== tool-ops-session-audit.sh =="
H="$HOOKS/tool-ops-session-audit.sh"
mkdir -p "$TEST_HOME/.claude/hooks"
cp "$HOOKS/block-claude-code-guide.sh" "$TEST_HOME/.claude/hooks/"
printf '{"session_id":"%s","hook_event_name":"SessionEnd"}' "$SID" > "$P"
run_hook "$H" "$P" "$NOGIT" AITOOLS_REPO_PATH="$REPO"
check "exit 0, no output" quiet0
check "audit line logged with 2 passes, 0 failures" contains "$(cat "$TEST_HOME/.claude/hooks/logs/tool-ops-audit.jsonl" 2>/dev/null || echo none)" '"test_pass":2,"test_fail":0'

echo "== SessionEnd/SessionStart shims without ait-harvest.py =="
for h in session-archive.sh harvest-session.sh session-catchup.sh; do
    printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionEnd"}' "$SID" "$NOGIT" > "$P"
    run_hook "$HOOKS/$h" "$P" "$NOGIT"
    check "$h: exit 0, no output" quiet0
    log="$TEST_HOME/.aitools/logs/${h%.sh}.log"
    check "$h: fallback log line" contains "$(cat "$log" 2>/dev/null || echo none)" "[${h%.sh}] [warn]"
done

finish_tests "test-hooks-smoke"
