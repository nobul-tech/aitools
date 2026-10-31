#!/usr/bin/env bash
# pr-dump.sh -- dump open PR status, checks, files and comments (scratch)
set -euo pipefail
out=/Users/new-jose/repos/aitools/.scratch/session-10cf255a-c/pr-dump
mkdir -p "$out"
gh pr list -R nobul-tech/aitools --state open --limit 50 --json number,title,baseRefName,headRefName,mergeable,mergeStateStatus,isDraft,createdAt > "$out/list.json"
for n in $(jq -r '.[].number' "$out/list.json"); do
  gh pr view "$n" -R nobul-tech/aitools --json number,title,baseRefName,headRefName,mergeable,mergeStateStatus,statusCheckRollup,files,comments,reviews,body > "$out/pr-$n.json"
  jq -r '"## #\(.number) \(.title)\nbase=\(.baseRefName) head=\(.headRefName) mergeable=\(.mergeable) state=\(.mergeStateStatus)\nchecks: " + ([.statusCheckRollup[]? | "\(.name // .context)=\(.conclusion // .state // .status)"] | join(", ")) + "\nfiles: " + ([.files[].path | select(startswith(".aitools/") | not)] | join(" ")) + "\n### body (first 60 lines)\n" + ((.body // "") | split("\n") | .[0:60] | join("\n")) + "\n### reviews\n" + ([.reviews[]? | "- [\(.state)] \(.author.login) \(.submittedAt): " + ((.body // "") | gsub("\n"; " ") | .[0:1500])] | join("\n")) + "\n### comments\n" + ([.comments[]? | "- \(.author.login) \(.createdAt): " + ((.body // "") | gsub("\n"; " ") | .[0:1500])] | join("\n")) + "\n"' "$out/pr-$n.json" > "$out/pr-$n.md"
done
jq -r '.[] | "\(.number)\t\(.baseRefName)\t\(.mergeable)\t\(.mergeStateStatus)\t\(.headRefName)\t\(.title)"' "$out/list.json"
