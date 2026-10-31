#!/usr/bin/env bash
# Dump merged PR bodies (>= #36) and open PR bodies to text for reading.
set -euo pipefail
d=/Users/new-jose/repos/aitools/.scratch/session-relnotes74
jq -r 'sort_by(.number) | .[] | select(.number >= 36) | "\n\n######## PR #\(.number) (\(.mergedAt)) \(.title)\n\(.url)  +\(.additions)/-\(.deletions) files=\(.files|length)\nFILES: \([.files[].path]|join(", "))\n\n\(.body)"' "$d/prs.json" > "$d/bodies.txt"
gh pr list -R nobul-tech/aitools --state open --limit 100 --json number,title,url,body,additions,deletions,files > "$d/open.json"
jq -r 'sort_by(.number) | .[] | "\n\n######## OPEN PR #\(.number) \(.title)\n\(.url)  +\(.additions)/-\(.deletions) files=\(.files|length)\nFILES: \([.files[].path]|join(", "))\n\n\(.body)"' "$d/open.json" > "$d/open.txt"
wc -l "$d/bodies.txt" "$d/open.txt"
