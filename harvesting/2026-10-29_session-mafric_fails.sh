#!/usr/bin/env bash
# Pull failed-step logs for the failed CI runs (read-only).
set -euo pipefail
out=/Users/new-jose/repos/aitools/.scratch/session-mafric
for id in 39891714493 39891264259 39890650263 39888735993 39873612279; do
  gh run view "$id" -R nobul-tech/aitools --log-failed > "$out/fail-$id.log" 2>&1 || echo "run $id: gh exit $?" >> "$out/fail-$id.log"
  grep -iE "FAIL|error|exit code|not ok|assert" "$out/fail-$id.log" | grep -v "^\s*$" | head -40 > "$out/fail-$id.grep" || echo "no matches" > "$out/fail-$id.grep"
done
echo done
