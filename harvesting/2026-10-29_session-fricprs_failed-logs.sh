#!/usr/bin/env bash
# Extract failing lines from failed CI runs (read-only).
set -euo pipefail
out=/Users/new-jose/repos/aitools/.scratch/session-fricprs/data
for id in 39891714493 39891264259 39890650263 39888735993 39873612279 39861915512 39861809999 39859094088; do
  echo "===== run $id"
  if gh run view "$id" -R nobul-tech/aitools --log-failed > "$out/run-$id.log" 2>&1; then
    grep -E "FAIL|::error|error:|Error|not ok|failed" "$out/run-$id.log" | head -25
  else
    echo "could not fetch log for $id"
  fi
done
