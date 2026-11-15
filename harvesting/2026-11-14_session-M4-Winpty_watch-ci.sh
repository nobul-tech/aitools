#!/usr/bin/env bash
# M4-Winpty: wait for PR checks to appear, then watch until they finish; final state to a log
set -uo pipefail
PR="${1:-148}"
S=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty/.scratch/session-M4-Winpty
n=0
until gh pr checks "$PR" -R nobul-tech/aitools > "$S/ci-checks.log" 2>&1; do
    if ! grep -q -i "no checks reported" "$S/ci-checks.log"; then
        # checks exist; non-zero exit means pending or failing -- watch it
        break
    fi
    n=$((n + 1))
    if [ "$n" -gt 40 ]; then echo "no checks after 40 tries" >> "$S/ci-checks.log"; exit 3; fi
    sleep 15
done
gh pr checks "$PR" -R nobul-tech/aitools --watch --interval 30 > "$S/ci-watch.log" 2>&1
rc=$?
gh pr checks "$PR" -R nobul-tech/aitools > "$S/ci-final.log" 2>&1
echo "watch exit $rc" >> "$S/ci-final.log"
exit "$rc"
