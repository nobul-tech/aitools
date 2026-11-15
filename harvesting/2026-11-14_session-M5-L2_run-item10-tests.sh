#!/usr/bin/env bash
# run-item10-tests.sh -- bash -n on the touched .sh files, then the installer suites
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
S="$WT/.scratch/session-M5-L2"
cd "$WT"
for f in scripts/aitools-install.sh tests/profile/test-install.sh; do
    if bash -n "$f"; then echo "bash -n OK $f"; else echo "bash -n FAIL $f"; fi
done
bash tests/profile/test-install.sh > "$S/test-install.log" 2>&1
echo "test-install.sh rc=$?"; tail -n 3 "$S/test-install.log"; grep -E "FAIL|skip" "$S/test-install.log"
bash tests/profile/test-config.sh > "$S/test-config.log" 2>&1
echo "test-config.sh rc=$?"; tail -n 3 "$S/test-config.log"; grep -E "FAIL" "$S/test-config.log" | head -n 20
