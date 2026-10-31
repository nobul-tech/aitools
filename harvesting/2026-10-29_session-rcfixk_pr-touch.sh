#!/usr/bin/env bash
# pr-touch.sh -- which open PR branches change the given files themselves
# (diff merge-base..branch). Usage: pr-touch.sh <file>...
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
for b in docs/m3-lead-plan feature/mf-config-no-machine feature/harness-rules-manifest docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay; do
    mb=$(git -C "$REPO" merge-base origin/main "origin/$b")
    ch=$(git -C "$REPO" diff --name-only "$mb" "origin/$b" -- "$@" | tr '\n' ' ')
    if [ -n "$ch" ]; then printf '%-36s %s\n' "$b" "$ch"; fi
done
echo done
