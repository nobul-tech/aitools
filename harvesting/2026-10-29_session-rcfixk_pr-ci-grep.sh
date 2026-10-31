#!/usr/bin/env bash
# pr-ci-grep.sh -- for each open PR branch, show CI test steps and grep given
# patterns in given files. Usage: pr-ci-grep.sh <file> <ERE pattern>
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
FILE="$1"
PAT="$2"
for b in docs/m3-lead-plan feature/mf-config-no-machine feature/harness-rules-manifest docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay; do
    if ! git -C "$REPO" cat-file -e "origin/$b:$FILE" 2>/dev/null; then
        printf '== %s: (no %s)\n' "$b" "$FILE"
        continue
    fi
    if git -C "$REPO" diff --quiet origin/main "origin/$b" -- "$FILE"; then
        printf '== %s: %s unchanged vs main\n' "$b" "$FILE"
        continue
    fi
    printf '== %s: %s CHANGED\n' "$b" "$FILE"
    git -C "$REPO" diff origin/main "origin/$b" -- "$FILE" | grep -nE "$PAT" | head -40
done
