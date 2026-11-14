#!/usr/bin/env bash
# M4-Winpty: run pre-commit and pre-push checks from the worktree, logs to scratch
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
S=$WT/.scratch/session-M4-Winpty
cd "$WT" || exit 1
bash "$WT/scripts/check-pre-commit.sh" > "$S/pre-commit.log" 2>&1
echo "pre-commit exit $?" > "$S/checks-summary.log"
bash "$WT/scripts/check-pre-push.sh" > "$S/pre-push.log" 2>&1
echo "pre-push exit $?" >> "$S/checks-summary.log"
