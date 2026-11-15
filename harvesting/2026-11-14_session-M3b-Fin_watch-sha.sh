#!/usr/bin/env bash
# Wait for every workflow run on a commit SHA to complete; print each conclusion.
# Usage: watch-sha.sh <sha> <max-seconds>
set -uo pipefail
sha="$1"; max="$2"
end=$(( $(date +%s) + max ))
while true; do
    out=$(gh run list --repo nobul-tech/aitools --commit "$sha" --json databaseId,workflowName,status,conclusion --jq '.[] | "\(.workflowName) \(.databaseId) \(.status) \(.conclusion)"' 2>&1)
    if [ -n "$out" ] && ! printf '%s\n' "$out" | grep -qv " completed "; then
        printf '%s\n' "$out"
        echo "RUNS DONE"
        exit 0
    fi
    if [ "$(date +%s)" -ge "$end" ]; then printf '%s\n' "$out"; echo "TIMEOUT"; exit 1; fi
    sleep 45
done
