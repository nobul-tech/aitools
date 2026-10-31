#!/usr/bin/env bash
# grep-branches.sh PATTERN [PATHSPEC...] -- git grep -E over every open PR head ref.
set -euo pipefail
R=/Users/new-jose/repos/aitools
pat="$1"; shift
for b in docs/m3-lead-plan feature/mf-config-no-machine docs/harness-approved-drafts feature/harness-rules-manifest docs/m3-approved-drafts docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit docs/m3-approved-intents feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay; do
  out=$(git -C "$R" grep -n -E "$pat" "origin/$b" -- "$@" 2>/dev/null || true)
  base=$(git -C "$R" grep -n -E "$pat" "origin/main" -- "$@" 2>/dev/null | sed "s#^origin/main:##" || true)
  if [ -n "$out" ]; then
    echo "== $b"
    printf '%s\n' "$out" | sed "s#^origin/$b:##" | grep -v -x -F -f <(printf '%s\n' "$base") || echo "   (same as main)"
  fi
done
