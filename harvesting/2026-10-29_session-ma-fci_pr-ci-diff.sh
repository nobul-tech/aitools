#!/usr/bin/env bash
# Show the check.yml diff each open PR carries against its merge base (scratch, read-only)
set -eu
repo=/Users/new-jose/repos/aitools
out=/Users/new-jose/repos/aitools/.scratch/session-ma-fci/pr-ci-diff.txt
: > "$out"
for n in 103 112 113 115 116; do
    head=$(gh pr view "$n" -R nobul-tech/aitools --json headRefName --jq .headRefName)
    git -C "$repo" fetch origin "$head" --quiet
    {
        echo "=== PR #$n ($head)"
        git -C "$repo" diff "origin/main...origin/$head" -- .github/workflows/check.yml | grep -E '^[+-] *- name:|^\+ *run:'
    } >> "$out"
done
echo "wrote $out"
