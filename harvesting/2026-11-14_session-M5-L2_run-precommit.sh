#!/usr/bin/env bash
# run-precommit.sh -- check-pre-commit.ps1 from the worktree, checks.log in scratch
set -uo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
S="$WT/.scratch/session-M5-L2"
mkdir -p "$S/checklogs"
cd "$WT"
AITOOLS_LOG_DIR="$(cygpath -w "$S/checklogs")" pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$WT/scripts/check-pre-commit.ps1")" > "$S/precommit-${1:-run}.log" 2>&1
echo "rc=$?"
grep -E "FAIL|WARN|PASS:|passed|failed|Summary|\[(FAIL|WARN)\]" "$S/precommit-${1:-run}.log" | tail -n 40
