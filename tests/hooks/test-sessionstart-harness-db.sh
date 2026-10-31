#!/usr/bin/env bash
# test-sessionstart-harness-db.sh -- tests for the two SessionStart hooks that
# call harness-db.py: shared/hooks/harness-db-sessionstart.sh and
# shared/hooks/scratch-init.sh.
#
# SessionStart plain stdout reaches Claude; stderr of an exit-0 hook does not.
# Covers, with a fake harness-db.py in an isolated HOME (~/.aitools/bin, the
# first candidate both hooks resolve; the real DB is never touched):
#   - success: helper output and "session <id> registered" on stdout, no
#     stderr, exit 0 (harness-db-sessionstart: also "This is Session Commander")
#   - a helper warning on stderr reaches stdout (2>&1)
#   - init fails / session start fails: "NOT registered" naming the failed
#     step, never "registered", exit 0 (SessionStart is never blocked)
#   - scratch-init: session dir + .current-session created, handoff line,
#     "Session scratch directory:" last
#   - no session_id: harness-db-sessionstart silent, exit 0
# The helper-dependent cases are skipped when no python3/python with sqlite3
# is available (the hooks skip the helper then too).
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run.
# Usage: bash tests/hooks/test-sessionstart-harness-db.sh
#        AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-sessionstart-harness-db.sh

set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hook-test-lib.sh"

HDB_HOOK="${TEST_HDB_HOOK_OVERRIDE:-$HOOKS/harness-db-sessionstart.sh}"
SI_HOOK="${TEST_SI_HOOK_OVERRIDE:-$HOOKS/scratch-init.sh}"

SID="abcdef1234-5678-90ab-cdef-000000000001"
PROJ="$WORK/proj"
mkdir -p "$PROJ" "$TEST_HOME/.aitools/bin"
git -C "$PROJ" init -q

# Fake helper: FAKE_HDB=ok|warn|fail-init|fail-start
cat > "$TEST_HOME/.aitools/bin/harness-db.py" <<'PYEOF'
import os, sys
mode = os.environ.get("FAKE_HDB", "ok")
cmd = sys.argv[1] if len(sys.argv) > 1 else ""
if cmd == "init":
    print("init: starting")  # stdout before the stderr traceback (order check)
    if mode == "fail-init":
        sys.stderr.write("Traceback (most recent call last):\nsqlite3.OperationalError: disk I/O error\n")
        sys.exit(1)
    if mode == "warn":
        sys.stderr.write("WARNING: harness DB schema is newer than this helper\n")
    print("Harness databases initialized.")
elif cmd == "session":
    if mode == "fail-start":
        sys.stderr.write("ERROR: session table locked\n")
        sys.exit(1)
    print("Session started: " + sys.argv[4])
PYEOF

payload() { printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$1" "$PROJ" > "$WORK/p.json"; }

for HOOK in "$HDB_HOOK" "$SI_HOOK"; do
    name="$(basename "$HOOK")"
    echo "== $name =="
    if [ -z "$PYBIN" ]; then
        skip "$name: helper cases (no python with sqlite3)"
        continue
    fi
    payload "$SID"

    run_hook "$HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=ok
    check "$name ok: exit 0" [ "$RC" -eq 0 ]
    check "$name ok: helper output on stdout" contains "$OUT" "Session started: $SID"
    check "$name ok: registered" contains "$OUT" "Harness DB: session $SID registered"
    check "$name ok: no stderr" [ -z "$ERR" ]

    run_hook "$HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=warn
    check "$name warn: helper warning reaches stdout" contains "$OUT" "WARNING: harness DB schema"
    check "$name warn: no stderr" [ -z "$ERR" ]
    check "$name warn: registered" contains "$OUT" "session $SID registered"

    run_hook "$HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=fail-init
    check "$name fail-init: exit 0" [ "$RC" -eq 0 ]
    check "$name fail-init: error text on stdout" contains "$OUT" "disk I/O error"
    check "$name fail-init: NOT registered, names init" contains "$OUT" "session $SID NOT registered (harness-db.py init failed"
    check "$name fail-init: never claims registered" eval '! contains "$OUT" "session $SID registered"'
    check "$name fail-init: points at the output above, not harness-db.log" contains "$OUT" "failed; the cause is in the harness-db.py output above)"
    check "$name fail-init: no harness-db.log pointer" eval '! contains "$OUT" "harness-db.log"'
    check "$name fail-init: helper stdout and stderr in order (PYTHONUNBUFFERED)" in_order "$OUT" "init: starting" "Traceback"

    run_hook "$HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=fail-start
    check "$name fail-start: NOT registered, names session start" contains "$OUT" "NOT registered (harness-db.py session start failed"
    check "$name fail-start: error text on stdout" contains "$OUT" "session table locked"
done

echo "== harness-db-sessionstart: identity line, no session id =="
if [ -n "$PYBIN" ]; then
    payload "$SID"
    run_hook "$HDB_HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=ok
    check "Session Commander line" contains "$OUT" "This is Session Commander abcdef1234."
fi
printf '{"cwd":"%s","hook_event_name":"SessionStart"}' "$PROJ" > "$WORK/p.json"
run_hook "$HDB_HOOK" "$WORK/p.json" "$PROJ"
check "no session_id: exit 0, no output" quiet0

echo "== scratch-init: scratch dir, handoff, last line =="
mkdir -p "$PROJ/.aitools/channel/handoffs"
: > "$PROJ/.aitools/channel/handoffs/handoff-test.md"
payload "$SID"
run_hook "$SI_HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=ok
check "exit 0" [ "$RC" -eq 0 ]
# Compare base names: the hook resolves the git root (/private/var/... on
# macOS) where $PROJ may be /var/...
ptr_base() { local p; p=$(cat "$PROJ/.scratch/.current-session"); printf '%s' "${p##*/}"; }
check ".current-session names session-<full id>" [ "$(ptr_base)" = "session-$SID" ]
check "session dir named with the full session id (never cut)" [ -d "$PROJ/.scratch/session-$SID" ]
check "no 10-char dir created" [ ! -d "$PROJ/.scratch/session-abcdef1234" ]
check "handoff line" contains "$OUT" "Handoff available: handoff-test.md"
check "last line is the scratch directory" contains "$(printf '%s\n' "$OUT" | tail -n 1)" "Session scratch directory: "
check "last line names the full-id dir" contains "$(printf '%s\n' "$OUT" | tail -n 1)" "/.scratch/session-$SID"
check "no stderr" [ -z "$ERR" ]

echo "== scratch-init: legacy 10-char dir of the same session is reused =="
LSID="fedcba9876-5432-10fe-dcba-000000000002"
mkdir -p "$PROJ/.scratch/session-fedcba9876"
payload "$LSID"
run_hook "$SI_HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=ok
check "legacy dir reused" [ "$(ptr_base)" = "session-fedcba9876" ]
check "no full-id dir beside the legacy one" [ ! -d "$PROJ/.scratch/session-$LSID" ]

echo "== scratch-init: unsafe session id falls back to mktemp =="
payload "../escape"
run_hook "$SI_HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=ok
check "unsafe id: exit 0" [ "$RC" -eq 0 ]
check "unsafe id: no dir outside .scratch" [ ! -d "$WORK/escape" ] && [ ! -d "$PROJ/escape" ]
check "unsafe id: pointer is a session-* dir in .scratch" contains "$(cat "$PROJ/.scratch/.current-session")" "$PROJ/.scratch/session-"

echo "== scratch-init: dated handoffs are discovered, newest announced (issue #138) =="
: > "$PROJ/.aitools/channel/handoffs/2026-10-22_10cf255a-c.md"
: > "$PROJ/.aitools/channel/handoffs/2026-06-21_session-46ee1c2b-1_handoff-verification.md"
: > "$PROJ/.aitools/channel/handoffs/2026-03-23_session-KHGOmVeNNM.md"
: > "$PROJ/.aitools/channel/handoffs/.gitkeep"
mkdir -p "$PROJ/.aitools/channel/handoffs/2026-10-30_missions"
payload "$SID"
run_hook "$SI_HOOK" "$WORK/p.json" "$PROJ" FAKE_HDB=ok
check "newest dated handoff announced" contains "$OUT" "Handoff available: 2026-10-22_10cf255a-c.md (4 total in"
check "undated legacy handoff not announced over a dated one" eval '! contains "$OUT" "Handoff available: handoff-test.md"'

finish_tests "test-sessionstart-harness-db"
