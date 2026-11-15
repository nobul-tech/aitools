#!/usr/bin/env bash
# old-lib-spinner.sh -- run the new menus suite (spinner cases) against the ORIGINAL lib
# (tree built by old-lib-tree.sh). Prints only the spinner lines and the totals.
set -uo pipefail
T="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib/.scratch/session-M5-L1/oldtree"
bash "$T/tests/menus/test-menu-choice.sh" 2>&1 | grep -E 'spinner|passed'
