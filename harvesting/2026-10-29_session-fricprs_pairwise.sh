#!/usr/bin/env bash
# Pairwise dry-run merges of open PR branches (git merge-tree; nothing written to refs).
set -uo pipefail
repo=/Users/new-jose/repos/aitools
branches="docs/m3-lead-plan feature/mf-config-no-machine feature/harness-rules-manifest docs/m3-approved-drafts docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit docs/m3-approved-intents feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay"
for a in $branches; do
  for b in $branches; do
    [ "$a" \< "$b" ] || continue
    out=$(git -C "$repo" merge-tree --write-tree --name-only "origin/$a" "origin/$b" 2>&1)
    rc=$?
    if [ "$rc" -eq 1 ]; then
      files=$(printf '%s\n' "$out" | sed -n '2,/^$/p' | grep -v '^$' | tr '\n' ' ')
      echo "CONFLICT $a x $b: $files"
    elif [ "$rc" -ne 0 ]; then
      echo "ERROR rc=$rc $a x $b: $out"
    fi
  done
done
