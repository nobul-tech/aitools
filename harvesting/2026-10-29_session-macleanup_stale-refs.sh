#!/usr/bin/env bash
# stale-refs.sh -- report (never delete) refs outside the PR flow (read-only)
set -euo pipefail
R=/Users/new-jose/repos/aitools
chk() {
  local ref="$1"
  if git -C "$R" merge-base --is-ancestor "$ref" origin/main; then c=contained; else c=not-contained; fi
  printf '%s %s %s %s\n' "$ref" "$(git -C "$R" log -1 --format='%h %cs' "$ref")" "$c" "$(git -C "$R" log -1 --format='%s' "$ref" | cut -c1-70)"
}
printf -- '--- local refs/mdmpkg\n'
for r in refs/mdmpkg/pr106 refs/mdmpkg/pr111 refs/mdmpkg/pr112; do chk "$r"; done
printf -- '--- remote branches with no PR #50-#132 head\n'
for b in master aigit-smoke/dd6fbde7-20260523T060352Z claude/fable-status-q9ch93 claude/great-cray-R3Ne4 claude/tender-goldberg-gae94k cursor/cloud-env-setup-28cd cursor/env-setup-agents-md-a271 cursor/rfc-mission-bridge-700b nobul-grok/consolidated-tools-provenance feature/m3-rekey-lib; do
  chk "origin/$b"
done
printf -- '--- #79 branch vs PR head\n'
git -C "$R" log --oneline cc597ec..origin/feature/m3-b3b-installer-config
printf -- '--- worktrees count\n'
git -C "$R" worktree list | wc -l
printf -- '--- local branches whose upstream is gone\n'
git -C "$R" for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | grep -c "gone" || printf '0\n'
