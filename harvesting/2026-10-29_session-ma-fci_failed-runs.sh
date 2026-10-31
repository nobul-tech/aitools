#!/usr/bin/env bash
# Summarise failed CI runs: job, step, FAIL/error lines (scratch, read-only)
set -eu
# scratch, read-only: no pipefail so a grep with no match does not abort
out=/Users/new-jose/repos/aitools/.scratch/session-ma-fci/failed-runs.txt
: > "$out"
for id in 39873612279 39861915512 39861809999 39859094088 39720365900 39719152527 39719101997 27527054612 27526218071 27523210139 27522676750 27522251437 27508321406; do
    {
        echo "=== run $id"
        gh run view "$id" -R nobul-tech/aitools --json headBranch,displayTitle,headSha,jobs \
            --jq '"branch=\(.headBranch) sha=\(.headSha[0:7]) title=\(.displayTitle)", (.jobs[] | select(.conclusion=="failure") | "  job=\(.name) step=" + ([.steps[] | select(.conclusion=="failure") | .name] | join(",")))'
        gh run view "$id" -R nobul-tech/aitools --log-failed 2>&1 | grep -E 'FAIL|::error|##\[error\]|not ok|Error:|error:' | grep -vE '\^\[\[36;1m' | cut -c1-330 | head -25
    } >> "$out" 2>&1
done
echo "wrote $out"
