#!/usr/bin/env bash
# verify.sh -- rebuild scratch copies and run both suites: wrapper libs (must
# pass) and the empty-line-is-default mutants (must fail). Prints summaries.
set -uo pipefail
W=/c/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
S="$W/.scratch/session-M2-D1"
perl "$S/make-lib.pl" "$W" || exit 1
perl "$S/mutate.pl" "$W" || exit 1

echo "== bash -n / pwsh parser =="
bash -n "$W/tests/menus/test-menu-choice.sh" && echo "bash -n OK"
pwsh -NoProfile -File "$W/.scratch/session-M2-Reask/parse.ps1" "$(cygpath -w "$W/tests/menus/test-menu-choice.ps1")"

echo "== --help / -Help =="
bash "$W/tests/menus/test-menu-choice.sh" --help | head -n 3
pwsh -NoProfile -File "$(cygpath -w "$W/tests/menus/test-menu-choice.ps1")" -Help | head -n 3

echo "== PS1 suite, wrapper lib =="
pwsh -NoProfile -File "$(cygpath -w "$S/suite/test-menu-choice.ps1")" > "$S/ps1-good.log" 2>&1; echo "rc=$?"
grep -E '^(FAIL|[0-9]+ passed)' "$S/ps1-good.log"

echo "== bash suite, wrapper lib (pty cases skip here) =="
bash "$S/suite/test-menu-choice.sh" > "$S/sh-good.log" 2>&1; echo "rc=$?"
grep -E '^(FAIL|SKIP|[0-9]+ passed)' "$S/sh-good.log"

echo "== bash suite, fake terminal, wrapper lib =="
perl "$S/make-fake.pl" "$W" || exit 1
bash "$S/suite-fake/test-menu-choice.sh" > "$S/sh-fake-good.log" 2>&1; echo "rc=$?"
grep -E 'FAIL|[0-9]+ passed' "$S/sh-fake-good.log"

echo "== PS1 suite, MUTANT (must fail) =="
pwsh -NoProfile -File "$(cygpath -w "$S/suite-mut/test-menu-choice.ps1")" > "$S/ps1-mut.log" 2>&1; echo "rc=$?"
grep -E 'FAIL|[0-9]+ passed' "$S/ps1-mut.log"

echo "== bash suite, fake terminal, MUTANT (must fail) =="
perl "$S/make-fake.pl" "$W" "$S/lib-mut/aitools-lib.sh" || exit 1
bash "$S/suite-fake/test-menu-choice.sh" > "$S/sh-fake-mut.log" 2>&1; echo "rc=$?"
grep -E 'FAIL|[0-9]+ passed' "$S/sh-fake-mut.log"
# leave suite-fake on the good lib
perl "$S/make-fake.pl" "$W" > /dev/null
