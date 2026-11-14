#!/usr/bin/env bash
# verify-ui.sh (M2-D2 scratch) -- the edited user-init suite in integ (real; pty
# cases skip here) and its fake-console copy. Logs in this directory.
set -uo pipefail
W=/c/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
S="$W/.scratch/session-M2-D2"
I="$W/.scratch/session-M2-Reask/integ"
bash -n "$W/tests/profile/test-user-init.sh" && echo "bash -n test-user-init.sh OK"
cp "$W/tests/profile/test-user-init.sh" "$I/tests/profile/" || exit 1
echo "== user-init suite in integ (pty cases skip here) =="
bash "$I/tests/profile/test-user-init.sh" > "$S/ui-integ.log" 2>&1; echo "rc=$?"
grep -E 'FAIL|skip|test-user-init:' "$S/ui-integ.log"
echo "== user-init suite, fake console =="
perl "$S/make-fake-ui.pl" "$W" || exit 1
bash "$I/tests/profile/test-user-init-fake.sh" > "$S/ui-fake.log" 2>&1; echo "rc=$?"
grep -E 'FAIL|interactive|reask|test-user-init:' "$S/ui-fake.log"
