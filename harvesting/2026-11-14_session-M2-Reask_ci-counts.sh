#!/usr/bin/env bash
# ci-counts.sh RUN_ID -- per job, the summary count lines of the suites this PR touches
set -uo pipefail
RUN="$1"
for job in $(gh run view "$RUN" --repo nobul-tech/aitools --json jobs --jq '.jobs[] | select(.name=="macos" or .name=="linux" or .name=="windows") | .databaseId'); do
    gh run view "$RUN" --repo nobul-tech/aitools --log --job "$job" > "$(dirname "$0")/ci-$job.tmp"
    perl -ne 'if (/^(\w+)\t(Menu-choice[^\t]*|Managed-file[^\t]*|User init[^\t]*|setup-user-skills[^\t]*|deploy-harness tests[^\t]*)\t\S+ (.*(passed|SKIP).*)$/) { print "$1 | $2 | $3\n" }' "$(dirname "$0")/ci-$job.tmp" | grep -E 'passed|SKIP' | grep -vE '^\S+ \| [^|]+ \| (PASS|SKIP [a-z])'
done
