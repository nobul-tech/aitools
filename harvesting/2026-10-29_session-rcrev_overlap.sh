#!/usr/bin/env bash
# For each open PR branch, list files it changes that this plan's batches also edit.
set -euo pipefail
R=/Users/new-jose/repos/aitools
PLANFILES=/Users/new-jose/repos/aitools/.scratch/session-rcrev/planfiles.txt
for pair in 97:docs/m3-lead-plan 98:feature/mf-config-no-machine 100:feature/harness-rules-manifest 101:docs/m3-approved-drafts 102:docs/mf-incidents 103:fix/mf-dotprofile-adopt-push 104:docs/mf-audit 105:docs/m3-approved-intents 106:feature/harness-hookin 108:fix/mf-audit-profile-json 109:fix/mf-audit-consumers 110:feature/harness-cursor-user-rules 111:feature/harness-mdm-followups 112:fix/mf-audit-claude-build 113:fix/mf-lib-runner-result 114:fix/mf-audit-config 115:fix/mf-lib-relay 116:fix/mf-installer-relay; do
  n=${pair%%:*}
  b=${pair#*:}
  git -C "$R" diff --name-only "origin/main...origin/$b" > /Users/new-jose/repos/aitools/.scratch/session-rcrev/pr-$n.txt
  hits=$(grep -x -F -f "$PLANFILES" /Users/new-jose/repos/aitools/.scratch/session-rcrev/pr-$n.txt | tr '\n' ' ' || true)
  echo "#$n $b: $hits"
done
