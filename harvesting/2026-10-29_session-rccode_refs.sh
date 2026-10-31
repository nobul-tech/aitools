#!/usr/bin/env bash
# Print local origin/<branch> SHA for each PR branch, and files touched vs origin/main
set -euo pipefail
R=/Users/new-jose/repos/aitools
git -C "$R" rev-parse origin/main
for b in fix/mf-installer-relay fix/mf-lib-relay fix/mf-audit-config fix/mf-lib-runner-result fix/mf-audit-claude-build feature/harness-mdm-followups feature/harness-cursor-user-rules fix/mf-audit-consumers fix/mf-audit-profile-json feature/harness-hookin fix/mf-dotprofile-adopt-push feature/harness-rules-manifest feature/mf-config-no-machine; do
  sha=$(git -C "$R" rev-parse "origin/$b" 2>/dev/null || echo MISSING)
  mb=$(git -C "$R" merge-base origin/main "origin/$b" 2>/dev/null || echo none)
  echo "== $b $sha base=${mb:0:7}"
  git -C "$R" diff --name-only "$mb" "origin/$b" -- scripts tests | tr '\n' ' '
  echo
done
