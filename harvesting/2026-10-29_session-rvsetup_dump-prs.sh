#!/usr/bin/env bash
# dump-prs.sh -- save PR metadata and diffs for review (scratch, read-only gh calls)
set -euo pipefail
out="/Users/new-jose/repos/aitools/.scratch/session-rvsetup"
for n in 98 100 103 109 110 112 113 114 115 116; do
    gh pr view "$n" -R nobul-tech/aitools --json number,title,state,body,files --jq '"#\(.number) [\(.state)] \(.title)\nFILES: \([.files[].path] | join(", "))\n\n\(.body)"' > "$out/pr-$n.txt"
    gh pr diff "$n" -R nobul-tech/aitools > "$out/pr-$n.diff"
    printf '%s done\n' "$n"
done
