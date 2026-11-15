#!/usr/bin/env bash
# wait-sha.sh FULL_SHA -- wait for the "CI" run on a commit to appear and
# complete, then print its id, jobs and conclusion. Scratch helper.
set -euo pipefail
sha="$1"
repo="nobul-tech/aitools"
here="$(cd "$(dirname "$0")" && pwd)"
tries=0
run=""
while [ -z "$run" ]; do
    run=$(gh run list --repo "$repo" --commit "$sha" --workflow CI --limit 1 --json databaseId --jq '.[0].databaseId // empty')
    if [ -n "$run" ]; then break; fi
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then echo "no CI run for $sha"; exit 3; fi
    sleep 10
done
echo "run id: $run"
bash "$here/wait-run.sh" "$run"
