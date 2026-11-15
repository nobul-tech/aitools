#!/usr/bin/env bash
# run-final-checks.sh -- os-guards suite and check-pre-push.ps1 from the worktree (logs in scratch)
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
S="$WT/.scratch/session-M5-L2"
mkdir -p "$S/checklogs"
cd "$WT"
bash tests/os-guards/test-os-guards.sh > "$S/os-guards.log" 2>&1
echo "os-guards rc=$?"; tail -n 2 "$S/os-guards.log"; grep -E "^.*FAIL" "$S/os-guards.log" | head
AITOOLS_LOG_DIR="$(cygpath -w "$S/checklogs")" pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$WT/scripts/check-pre-push.ps1")" > "$S/prepush.log" 2>&1
echo "check-pre-push rc=$?"
grep -E "\[(PASS|FAIL|WARN|SKIP)\]|SUMMARY" "$S/prepush.log"
