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
    # Fake helper: exits 1 for the subcommands listed in FAKE_FAIL (comma list)
    cat > "$TEST_HOME/.aitools/bin/harness-db.py" <<'PYEOF'
import os, sys
cmd = sys.argv[1] if len(sys.argv) > 1 else ""
if cmd in os.environ.get("FAKE_FAIL", "").split(","):
    sys.stderr.write("helper failed: " + cmd + "\n")
    sys.exit(1)
print("ok: " + cmd)
PYEOF
    SE_LOG="$TEST_HOME/.aitools/logs/harness-db-sessionend.log"
    run_hook "$H" "$P" "$NOGIT" FAKE_FAIL=
    check "all steps ok: exit 0" [ "$RC" -eq 0 ]
    check "all steps ok: says ended, events processed, JSON exported" contains "$OUT" "session $SID ended, events processed, JSON exported"
    check "all steps ok: no hook log line" [ ! -f "$SE_LOG" ]
    run_hook "$H" "$P" "$NOGIT" FAKE_FAIL=session,export
    check "two steps fail: exit 0 (never blocks session end)" [ "$RC" -eq 0 ]
    check "two steps fail: status names them" contains "$OUT" "session $SID end incomplete (harness-db.py session end, export failed"
    check "two steps fail: never claims JSON exported" eval '! contains "$OUT" "JSON exported"'
    check "two steps fail: helper stderr kept for the user" contains "$ERR" "helper failed: export"
    # cat fails when the log is missing; the "none" sentinel then fails contains
    check "two steps fail: hook log line" contains "$(cat "$SE_LOG" 2>/dev/null || echo none)" "[harness-db-sessionend] [warn] session $SID: harness-db.py session end, export failed"
    rm -f "$TEST_HOME/.aitools/bin/harness-db.py"
fi

echo "== tool-ops-session-audit.sh =="
H="$HOOKS/tool-ops-session-audit.sh"
mkdir -p "$TEST_HOME/.claude/hooks"
cp "$HOOKS/block-claude-code-guide.sh" "$TEST_HOME/.claude/hooks/"
printf '{"session_id":"%s","hook_event_name":"SessionEnd"}' "$SID" > "$P"
run_hook "$H" "$P" "$NOGIT" AITOOLS_REPO_PATH="$REPO"
check "exit 0, no output" quiet0
# cat fails when the log is missing; the "none" sentinel then fails contains
check "audit line logged with 2 passes, 0 failures" contains "$(cat "$TEST_HOME/.claude/hooks/logs/tool-ops-audit.jsonl" 2>/dev/null || echo none)" '"test_pass":2,"test_fail":0'

echo "== SessionEnd/SessionStart shims without ait-harvest.py =="
for h in session-archive.sh harvest-session.sh session-catchup.sh; do
    printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionEnd"}' "$SID" "$NOGIT" > "$P"
    run_hook "$HOOKS/$h" "$P" "$NOGIT"
    check "$h: exit 0, no output" quiet0
    log="$TEST_HOME/.aitools/logs/${h%.sh}.log"
    # cat fails when the log is missing; the "none" sentinel then fails contains
    check "$h: fallback log line" contains "$(cat "$log" 2>/dev/null || echo none)" "[${h%.sh}] [warn]"
done

echo "== hook-test-lib self-test: no JSON parser counts as skip, never ok =="
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"x"}}' > "$WORK/out.txt"
OUT="$(cat "$WORK/out.txt")"
_pass=$PASS
_skip=$SKIP
export HOOK_TEST_NO_JSON=1
check "ctx_is without a parser (expected: skip)" ctx_is PreToolUse "x"
check "ctx_has without a parser (expected: skip)" ctx_has PreToolUse "x"
unset HOOK_TEST_NO_JSON
_skipped=$((SKIP - _skip))
_passed=$((PASS - _pass))
SKIP=$_skip  # the two simulated skips are the subject of this test, not real skips
check "the two checks were skipped, not passed" [ "$_skipped" -eq 2 ]
check "no pass was counted for them" [ "$_passed" -eq 0 ]

finish_tests "test-hooks-smoke"
