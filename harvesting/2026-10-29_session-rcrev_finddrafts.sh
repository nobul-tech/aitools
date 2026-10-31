#!/usr/bin/env bash
# Locate the draft folders the plan cites, across all remote branches.
set -euo pipefail
R=/Users/new-jose/repos/aitools
for b in $(git -C "$R" for-each-ref --format='%(refname:short)' refs/remotes/origin); do
  git -C "$R" ls-tree -r --name-only "$b" -- .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/ 2>/dev/null \
    | grep -E "S3-H2-Manifest-drafts|S3-H2-MDM-drafts|S3-H2-DraftsM3-drafts/reference/user-repo|S3-FanPlan|S3-AnsA-report|S3-AnsB-report" \
    | sed "s|^|$b: |" || true
done
echo "--- worktrees"
find /Users/new-jose/repos/aitools/.claude/worktrees -maxdepth 6 -type d \( -name "S3-H2-Manifest*" -o -name "S3-H2-MDM*" -o -name "S3-H2-DraftsM3*" \) 2>/dev/null || true
