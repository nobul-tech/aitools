#!/usr/bin/env bash
# old-lib-tree.sh -- build a tree with the ORIGINAL (origin/main) libs and the NEW tests,
# to prove the new test cases fail against the defect. Usage: old-lib-tree.sh
set -euo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
T="$WT/.scratch/session-M5-L1/oldtree"
rm -rf "$T"
mkdir -p "$T/scripts" "$T/tests/logging" "$T/tests/menus" "$T/tests/managed-files"
git -C "$WT" cat-file -p origin/main:scripts/aitools-lib.sh > "$T/scripts/aitools-lib.sh"
git -C "$WT" cat-file -p origin/main:scripts/aitools-lib.ps1 > "$T/scripts/aitools-lib.ps1"
cp "$WT/scripts/aitools" "$WT/scripts/aitools.ps1" "$T/scripts/"
cp "$WT/tests/logging/test-logging.sh" "$WT/tests/logging/test-logging.ps1" "$T/tests/logging/"
cp "$WT/tests/menus/test-menu-choice.sh" "$T/tests/menus/"
cp "$WT/tests/managed-files/pty-run.py" "$T/tests/managed-files/"
echo "== old lib, new bash logging tests"
bash "$T/tests/logging/test-logging.sh" | grep -E '^FAIL|passed' || true
echo "== old lib, new PowerShell logging tests"
pwsh -NoProfile -File "$(cygpath -w "$T/tests/logging/test-logging.ps1")" | grep -E '^FAIL|passed' || true
