#!/usr/bin/env bash
# Run test-post-push-step7.sh against the pre-fix check-post-push twins (0c667a8).
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/m5-checks
S=$WT/.scratch/session-M5-C2
mkdir -p "$S/old"
git -C "$WT" show 0c667a8:scripts/check-post-push.sh > "$S/old/check-post-push.sh"
git -C "$WT" show 0c667a8:scripts/check-post-push.ps1 > "$S/old/check-post-push.ps1"
rc=0
POST_PUSH_SH="$S/old/check-post-push.sh" POST_PUSH_PS1="$S/old/check-post-push.ps1" \
    bash "$WT/tests/check-post-push/test-post-push-step7.sh" || rc=$?
echo "exit: $rc"
