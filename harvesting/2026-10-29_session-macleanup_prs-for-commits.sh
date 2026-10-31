#!/usr/bin/env bash
# prs-for-commits.sh -- map commits to PR numbers (read-only)
set -euo pipefail
for c in 075c3da 62442cb be46ce8 1d67da9; do
  printf '%s -> ' "$c"
  gh api "repos/nobul-tech/aitools/commits/$c/pulls" --jq '[.[] | "#\(.number) \(.state) \(.title)"] | join("; ")'
done
