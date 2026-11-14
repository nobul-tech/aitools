#!/usr/bin/env bash
# check-staged.sh -- bash -n on the staged aitools-lib.sh, and show what is left unstaged
set -euo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
S="$WT/.scratch/session-M5-L1"
git -C "$WT" cat-file -p :scripts/aitools-lib.sh > "$S/staged-lib.tmp"
bash -n "$S/staged-lib.tmp"
echo "staged lib: bash -n OK"
grep -c '_aitlib_log_append' "$S/staged-lib.tmp" || echo "staged lib: no item-2 helper (expected)"
grep -c '_spinner_traps_set' "$S/staged-lib.tmp"
git -C "$WT" diff --stat
