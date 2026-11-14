#!/usr/bin/env bash
# verify-menus.sh (M2-D2 scratch) -- syntax checks, copy the edited menu suites
# into integ, run them there (bash: pty cases skip without pywinpty), run the
# bash suite on the fake terminal (make-fake.pl). Logs in this directory.
set -uo pipefail
W=/c/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
S="$W/.scratch/session-M2-D2"
I="$W/.scratch/session-M2-Reask/integ"

echo "== bash -n / pwsh parser =="
bash -n "$W/tests/menus/test-menu-choice.sh" && echo "bash -n test-menu-choice.sh OK"
bash -n "$W/tests/profile/test-user-init.sh" && echo "bash -n test-user-init.sh OK"
pwsh -NoProfile -File "$W/.scratch/session-M2-Reask/parse.ps1" "$(cygpath -w "$W/tests/menus/test-menu-choice.ps1")"

echo "== --help =="
bash "$W/tests/menus/test-menu-choice.sh" --help | tail -n 3
pwsh -NoProfile -File "$(cygpath -w "$W/tests/menus/test-menu-choice.ps1")" -Help | tail -n 3

echo "== copy into integ =="
cp "$W/tests/menus/test-menu-choice.sh" "$W/tests/menus/test-menu-choice.ps1" "$I/tests/menus/" || exit 1
cp "$W/tests/profile/test-user-init.sh" "$I/tests/profile/" || exit 1
echo copied

echo "== bash suite in integ (real lib; pty cases skip here) =="
bash "$I/tests/menus/test-menu-choice.sh" > "$S/sh-integ.log" 2>&1; echo "rc=$?"
grep -E '^(FAIL|SKIP|[0-9]+ passed)' "$S/sh-integ.log"

echo "== bash suite on the fake terminal =="
perl "$S/make-fake.pl" "$W" || exit 1
bash "$S/suite-fake/test-menu-choice.sh" > "$S/sh-fake.log" 2>&1; echo "rc=$?"
grep -E '^(FAIL|SKIP|[0-9]+ passed)' "$S/sh-fake.log"

echo "== PS1 suite in integ =="
pwsh -NoProfile -File "$(cygpath -w "$I/tests/menus/test-menu-choice.ps1")" > "$S/ps1-integ.log" 2>&1; echo "rc=$?"
grep -E '^(FAIL|SKIP|[0-9]+ passed)' "$S/ps1-integ.log"
