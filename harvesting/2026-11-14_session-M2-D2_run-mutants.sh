#!/usr/bin/env bash
# run-mutants.sh (M2-D2 scratch) -- both suites against the mutants: the new
# real-menu cases must FAIL. Prints the FAIL lines that mention the real menus.
set -uo pipefail
W=/c/Users/jdpal/repos/aitools/.claude/worktrees/menus-reask
S="$W/.scratch/session-M2-D2"
perl "$S/mutate.pl" "$W" || exit 1
echo "== bash, fake terminal, MUTANT =="
bash "$S/mut-sh/test-menu-choice.sh" > "$S/sh-mut.log" 2>&1; echo "rc=$?"
grep -E '^(FAIL|[0-9]+ passed)' "$S/sh-mut.log"
echo "== PS1, MUTANT =="
pwsh -NoProfile -File "$(cygpath -w "$S/mut-ps/tests/menus/test-menu-choice.ps1")" > "$S/ps1-mut.log" 2>&1; echo "rc=$?"
grep -E '^(FAIL|[0-9]+ passed)' "$S/ps1-mut.log"
