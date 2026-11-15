#!/usr/bin/env bash
# M4-Winpty: wait until the "CI" run for a head sha exists and every job has completed;
# write run id, conclusion and per-job conclusions to a log. Usage: wait-ci-run2.sh <sha>
set -uo pipefail
SHA="$1"
S=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty/.scratch/session-M4-Winpty
OUT="$S/ci2-$SHA.log"
n=0
id=""
while [ -z "$id" ]; do
    id=$(gh api "repos/nobul-tech/aitools/actions/runs?head_sha=$SHA" --jq '.workflow_runs[] | select(.name == "CI") | .id' 2>/dev/null | head -n 1)
    [ -n "$id" ] && break
    n=$((n + 1))
    if [ "$n" -gt 60 ]; then echo "no CI run for $SHA after 15 min" > "$OUT"; exit 3; fi
    sleep 15
done
echo "run $id" > "$OUT"
while true; do
    total=$(gh api "repos/nobul-tech/aitools/actions/runs/$id/jobs" --jq '.jobs | length' 2>/dev/null)
    done_n=$(gh api "repos/nobul-tech/aitools/actions/runs/$id/jobs" --jq '[.jobs[] | select(.status == "completed")] | length' 2>/dev/null)
    rstatus=$(gh api "repos/nobul-tech/aitools/actions/runs/$id" --jq '.status' 2>/dev/null)
    if [ -n "$total" ] && [ "$total" -gt 0 ] && [ "$total" = "$done_n" ] && [ "$rstatus" = "completed" ]; then break; fi
    sleep 30
done
gh api "repos/nobul-tech/aitools/actions/runs/$id" --jq '"conclusion " + (.conclusion // "none") + " " + .html_url' >> "$OUT"
gh api "repos/nobul-tech/aitools/actions/runs/$id/jobs" --jq '.jobs[] | [.name, (.conclusion // "none"), (.id|tostring), .html_url] | @tsv' >> "$OUT"
