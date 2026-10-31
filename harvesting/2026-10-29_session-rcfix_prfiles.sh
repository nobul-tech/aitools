#!/usr/bin/env bash
# List which open-PR branches change the given files versus origin/main.
set -euo pipefail
R=/Users/new-jose/repos/aitools
for b in docs/m3-lead-plan feature/mf-config-no-machine feature/harness-rules-manifest docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay; do
    files=$(git -C "$R" diff --name-only "origin/main...origin/$b" -- "$@" 2>&1) || files="ERR: $files"
    if [ -n "$files" ]; then
        echo "== $b"
        echo "$files"
    fi
done
