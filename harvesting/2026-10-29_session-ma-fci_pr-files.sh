#!/usr/bin/env bash
# For each open PR: files list, CI-file touch, tests touched, check rollup (scratch, read-only)
set -eu
out=/Users/new-jose/repos/aitools/.scratch/session-ma-fci/pr-files.txt
: > "$out"
for n in $(gh pr list -R nobul-tech/aitools --state open --limit 50 --json number --jq '.[].number'); do
    {
        echo "=== PR #$n"
        gh pr view "$n" -R nobul-tech/aitools --json title,headRefName,mergeStateStatus,createdAt,files,statusCheckRollup \
            --jq '"title=\(.title)\nhead=\(.headRefName) merge=\(.mergeStateStatus) created=\(.createdAt)\nchecks=" + ([.statusCheckRollup[] | "\(.name):\(.conclusion)"] | join(" ")) + "\nfiles=" + ([.files[].path] | join(" "))'
    } >> "$out" 2>&1
done
echo "wrote $out"
