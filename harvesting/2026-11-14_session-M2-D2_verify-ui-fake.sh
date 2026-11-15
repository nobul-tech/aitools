#!/usr/bin/env bash
# verify-ui-fake.sh (M2-D2 scratch) -- only the fake-console user-init run.
set -uo pipefail
W=/c/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
S="$W/.scratch/session-M2-D2"
I="$W/.scratch/session-M2-Reask/integ"
perl "$S/make-fake-ui.pl" "$W" || exit 1
bash "$I/tests/profile/test-user-init-fake.sh" > "$S/ui-fake.log" 2>&1; echo "rc=$?"
grep -E 'FAIL|interactive|reask|test-user-init:' "$S/ui-fake.log"
