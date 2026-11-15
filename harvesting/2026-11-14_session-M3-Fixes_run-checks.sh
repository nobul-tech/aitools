#!/usr/bin/env bash
# Run the repo's pre-commit, pre-push and post-push checks (.ps1 halves on Windows) from the worktree; logs in scratch.
set -uo pipefail
W=C:/Users/jdpal/repos/aitools/.claude/worktrees/console-profile
S=$W/.scratch/session-M3-Fixes
cd "$W" || exit 1
for c in check-pre-commit check-pre-push check-post-push; do
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$W/scripts/$c.ps1" > "$S/$c.log" 2>&1
    echo "$c exit $?"
    grep -E "FAIL|WARN" "$S/$c.log" | head -n 25
    tail -n 4 "$S/$c.log"
done
