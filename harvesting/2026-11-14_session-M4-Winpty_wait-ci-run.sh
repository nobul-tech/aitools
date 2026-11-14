#!/usr/bin/env bash
# M4-Winpty: wait until the CI (check.yml) run for a head sha exists and completes; print its jobs
set -uo pipefail
SHA="$1"
S=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty/.scratch/session-M4-Winpty
OUT="$S/ci-run-$SHA.log"
n=0
id=""
while [ -z "$id" ]; do
    id=$(gh api "repos/nobul-tech/aitools/actions/runs?head_sha=$SHA" --jq '.workflow_runs[] | select(.name == "CI") | .id' | head -n 1)
    if [ -n "$id" ]; then break; fi
    n=$((n + 1))
    if [ "$n" -gt 60 ]; then echo "no CI run for $SHA after 15 min" > "$OUT"; exit 3; fi
    sleep 15
done
echo "run $id" > "$OUT"
status=""
while [ "$status" != "completed" ]; do
    status=$(gh api "repos/nobul-tech/aitools/actions/runs/$id" --jq '.status')
    [ "$status" = "completed" ] || sleep 30
done
gh api "repos/nobul-tech/aitools/actions/runs/$id" --jq '"conclusion " + .conclusion + " " + .html_url' >> "$OUT"
gh api "repos/nobul-tech/aitools/actions/runs/$id/jobs" --jq '.jobs[] | [.name, .conclusion, .id, .html_url] | @tsv' >> "$OUT"
