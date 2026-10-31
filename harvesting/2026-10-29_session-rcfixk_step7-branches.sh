#!/usr/bin/env bash
# step7-branches.sh -- for each open PR branch: does it contain 8e490d7 (step 7
# always runs), and does its check-pre-push.sh/.ps1 differ from main's?
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
for b in docs/m3-lead-plan feature/mf-config-no-machine feature/harness-rules-manifest docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay; do
    if git -C "$REPO" merge-base --is-ancestor 8e490d7 "origin/$b"; then has=yes; else has=no; fi
    d=""
    for f in scripts/check-pre-push.sh scripts/check-pre-push.ps1; do
        if git -C "$REPO" diff --quiet origin/main "origin/$b" -- "$f"; then d="$d same"; else d="$d DIFF"; fi
    done
    # does the branch itself change the file relative to its merge base with main?
    mb=$(git -C "$REPO" merge-base origin/main "origin/$b")
    own=""
    for f in scripts/check-pre-push.sh scripts/check-pre-push.ps1; do
        if git -C "$REPO" diff --quiet "$mb" "origin/$b" -- "$f"; then own="$own untouched"; else own="$own CHANGED"; fi
    done
    printf '%-36s has-8e490d7=%s vs-main:%s  branch-own:%s\n' "$b" "$has" "$d" "$own"
done
