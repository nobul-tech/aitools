#!/usr/bin/env bash
# run-checks.sh -- run check-pre-commit.ps1 and check-pre-push.ps1 from the
# docs worktree with logs in scratch; print the summary lines.
set -uo pipefail
wt="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-docs"
export AITOOLS_LOG_DIR="$wt/.scratch/session-M5-Fixes/logs"
cd "$wt" || exit 1
pwsh -NoProfile -ExecutionPolicy Bypass -File "$wt/scripts/check-pre-commit.ps1" > "$AITOOLS_LOG_DIR/pre-commit.log" 2>&1
echo "pre-commit exit: $?"
grep -E 'FAIL|PASS.*20|Summary|passed|failed' "$AITOOLS_LOG_DIR/pre-commit.log" | tail -n 15
pwsh -NoProfile -ExecutionPolicy Bypass -File "$wt/scripts/check-pre-push.ps1" > "$AITOOLS_LOG_DIR/pre-push.log" 2>&1
echo "pre-push exit: $?"
grep -E 'FAIL|Summary|passed|failed| 7 ' "$AITOOLS_LOG_DIR/pre-push.log" | tail -n 15
