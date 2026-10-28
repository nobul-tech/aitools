#!/usr/bin/env bash
# Wait (up to 12h) for PR #123 to be MERGED; CLOSED is tolerated (accidental close, may be reopened).
set -euo pipefail
deadline=$(( $(date +%s) + 12*3600 ))
while :; do
    state=$(gh pr view 123 -R nobul-tech/aitools --json state --jq .state 2>&1) || state="error"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [wait-123b] [info] state=$state"
    if [ "$state" = "MERGED" ]; then exit 0; fi
    if [ "$(date +%s)" -ge "$deadline" ]; then exit 4; fi
    sleep 300
done
