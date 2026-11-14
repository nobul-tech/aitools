#!/usr/bin/env bash
# old-relay-tree.sh -- run the new relay cases of test-menu-choice.ps1 against the
# relay-outbound-prompt.ps1 of HEAD (before item 5), to show the tests discriminate.
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
T="$WT/.scratch/session-M5-L2/oldtree"
rm -rf "$T"
mkdir -p "$T/scripts" "$T/tests/menus" "$T/tests/managed-files"
cp "$WT/scripts/aitools-lib.ps1" "$T/scripts/"
git -C "$WT" show HEAD:scripts/relay-outbound-prompt.ps1 > "$T/scripts/relay-outbound-prompt.ps1"
cp "$WT/tests/menus/test-menu-choice.ps1" "$T/tests/menus/"
cp "$WT/tests/managed-files/pty-run.py" "$T/tests/managed-files/"
pwsh -NoProfile -File "$T/tests/menus/test-menu-choice.ps1" > "$WT/.scratch/session-M5-L2/old-relay.log" 2>&1
echo "rc=$?"
grep -E "^(FAIL|SKIP) relay|passed" "$WT/.scratch/session-M5-L2/old-relay.log"
