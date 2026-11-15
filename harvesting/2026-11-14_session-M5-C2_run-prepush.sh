#!/usr/bin/env bash
# Run check-pre-push.ps1 from the worktree, logs into scratch. Arg 1: label.
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/m5-checks
S=$WT/.scratch/session-M5-C2
label="${1:-run}"
cd "$WT"
mkdir -p "$S/logs-prepush-$label"
rc=0
AITOOLS_LOG_DIR="$(cygpath -w "$S/logs-prepush-$label")" pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$WT/scripts/check-pre-push.ps1")" > "$S/prepush-$label.log" 2>&1 || rc=$?
perl -pe 's/\e\[[0-9;]*m//g' "$S/prepush-$label.log" | grep -E "\[(FAIL|WARN|PASS|SKIP)\]|SUMMARY" | tail -n 30
echo "check-pre-push exit: $rc"
