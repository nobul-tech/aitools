#!/usr/bin/env bash
# For each failed CI run id, print failing jobs and failing steps, plus the error lines.
set -euo pipefail
for id in 39891714493 39891264259 39890650263 39888735993 39873612279 39861915512 39861809999 39859094088; do
    echo "=== run $id"
    gh run view "$id" -R nobul-tech/aitools --json jobs,headSha,displayTitle \
        --jq '.displayTitle + " sha=" + .headSha, (.jobs[] | select(.conclusion=="failure") | "  JOB " + .name + " :: " + ([.steps[] | select(.conclusion=="failure") | .name] | join(", ")))'
    if ! gh run view "$id" -R nobul-tech/aitools --log-failed > /Users/new-jose/repos/aitools/.scratch/session-fricsess/run-$id.log 2>&1; then
        echo "  (log-failed unavailable)"
        continue
    fi
    grep -E "FAIL|not ok|Error|error:|ERROR|AssertionError|exit code" /Users/new-jose/repos/aitools/.scratch/session-fricsess/run-$id.log | head -12 | cut -c1-260
done
