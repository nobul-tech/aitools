#!/usr/bin/env bash
# wait-run.sh RUN_ID -- wait until a GitHub Actions run completes, then print
# each job's name and conclusion and the run conclusion. Scratch helper.
set -euo pipefail
run="$1"
repo="nobul-tech/aitools"
tries=0
while true; do
    status=$(gh run view "$run" --repo "$repo" --json status --jq .status)
    if [ "$status" = "completed" ]; then break; fi
    tries=$((tries + 1))
    if [ "$tries" -gt 180 ]; then echo "timeout waiting for run $run (status $status)"; exit 3; fi
    sleep 20
done
gh run view "$run" --repo "$repo" --json conclusion,headSha,jobs --jq '"run conclusion: \(.conclusion) sha: \(.headSha)", (.jobs[] | "\(.name): \(.conclusion)")'
