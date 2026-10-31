#!/usr/bin/env bash
# pr-conflicts.sh -- per-PR conflicts vs origin/main, and pairwise file overlap (scratch)
set -euo pipefail
R=/Users/new-jose/repos/aitools
git -C "$R" fetch origin --quiet
prs="97:docs/m3-lead-plan 98:feature/mf-config-no-machine 99:docs/harness-approved-drafts 100:feature/harness-rules-manifest 101:docs/m3-approved-drafts 102:docs/mf-incidents 103:fix/mf-dotprofile-adopt-push 104:docs/mf-audit 105:docs/m3-approved-intents 106:feature/harness-hookin 108:fix/mf-audit-profile-json 109:fix/mf-audit-consumers 110:feature/harness-cursor-user-rules 111:feature/harness-mdm-followups 112:fix/mf-audit-claude-build 113:fix/mf-lib-runner-result 114:fix/mf-audit-config 115:fix/mf-lib-relay 116:fix/mf-installer-relay"
echo "== vs origin/main (merge-tree) =="
for p in $prs; do
  n=${p%%:*}; b=${p#*:}
  behind=$(git -C "$R" rev-list --count "origin/$b..origin/main")
  ahead=$(git -C "$R" rev-list --count "origin/main..origin/$b")
  if git -C "$R" merge-tree --write-tree --name-only origin/main "origin/$b" > /tmp/mt.$$ 2>&1; then
    echo "#$n clean  ahead=$ahead behind=$behind"
  else
    echo "#$n CONFLICT ahead=$ahead behind=$behind: $(tail -n +2 /tmp/mt.$$ | grep -v '^$' | grep -v '^Auto-merging' | tr '\n' ' ')"
  fi
done
rm -f /tmp/mt.$$
echo "== files per PR (excluding .aitools/) =="
for p in $prs; do
  n=${p%%:*}; b=${p#*:}
  base=$(git -C "$R" merge-base origin/main "origin/$b")
  echo "#$n: $(git -C "$R" diff --name-only "$base" "origin/$b" | grep -v '^\.aitools/' | tr '\n' ' ')"
done
