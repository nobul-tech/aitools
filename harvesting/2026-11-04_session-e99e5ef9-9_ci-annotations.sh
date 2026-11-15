#!/usr/bin/env bash
# Print every check-run annotation (warnings, notices, failures) of each job
# of a run. Usage: ci-annotations.sh <run id>
set -euo pipefail
RUN="$1"
gh api "repos/nobul-tech/aitools/actions/runs/$RUN/jobs?per_page=100" \
  --jq '.jobs[] | "\(.name)\t\(.check_run_url)"' | while IFS=$'\t' read -r name url; do
    printf '== %s\n' "$name"
    gh api "${url#https://api.github.com/}/annotations" \
      --jq '.[] | "  [\(.annotation_level)] \(.title // "") :: \(.message | gsub("\n"; " "))"'
done
