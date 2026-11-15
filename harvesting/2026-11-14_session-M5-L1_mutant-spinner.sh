#!/usr/bin/env bash
# mutant-spinner.sh -- the NEW lib with the owner watch removed (while true), to prove the
# KILL/TERM-of-its-shell cases detect a spinner that outlives its shell.
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
T="$WT/.scratch/session-M5-L1/mutanttree"
rm -rf "$T"
mkdir -p "$T/scripts" "$T/tests/menus" "$T/tests/managed-files"
perl -pe 's/while kill -0 "\$owner" 2>\/dev\/null; do/while true; do/' "$WT/scripts/aitools-lib.sh" > "$T/scripts/aitools-lib.sh"
grep -c 'while true; do' "$T/scripts/aitools-lib.sh"
cp "$WT/tests/menus/test-menu-choice.sh" "$T/tests/menus/"
cp "$WT/tests/managed-files/pty-run.py" "$T/tests/managed-files/"
bash "$T/tests/menus/test-menu-choice.sh" 2>&1 | grep -E 'spinner \((KILL|TERM) of|passed'
