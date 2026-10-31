#!/usr/bin/env bash
# prfiles.sh FILE... -- for each open PR branch, list which of FILE it changes vs origin/main (merge-base diff)
set -euo pipefail
R=/Users/new-jose/repos/aitools
branches="docs/m3-lead-plan feature/mf-config-no-machine feature/harness-rules-manifest docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay"
for b in $branches; do
    files=$(git -C "$R" diff --name-only "origin/main...origin/$b")
    for f in "$@"; do
        if printf '%s\n' "$files" | grep -qxF "$f"; then
            printf '%s\t%s\n' "$b" "$f"
        fi
    done
done
echo "done"
