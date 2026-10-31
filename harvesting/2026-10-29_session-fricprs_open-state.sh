#!/usr/bin/env bash
# Current mergeability of open PRs (read-only).
set -euo pipefail
gh pr list -R nobul-tech/aitools --state open --limit 50 --json number,mergeable,mergeStateStatus,baseRefName,headRefOid,updatedAt \
  --jq '.[] | "\(.number) \(.mergeable) \(.mergeStateStatus) base=\(.baseRefName) head=\(.headRefOid[0:7]) updated=\(.updatedAt)"'
