#!/usr/bin/env bash
# apply-merged.sh -- in a temp clone, merge origin/main with each open PR head (one
# at a time, as MERGE-ALL's merge commits would) and apply every main draft file to
# the merge result. Prints merge status and apply verdicts.
set -uo pipefail
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Fix-drafts/code
S=/Users/new-jose/repos/aitools/.scratch/session-rcfixc/apply-all.sh
T=$(mktemp -d /tmp/rcfixc-merge.XXXXXX)
git clone --quiet /Users/new-jose/repos/aitools "$T/r"
cd "$T/r" || exit 1
git fetch --quiet /Users/new-jose/repos/aitools "+refs/remotes/origin/*:refs/remotes/src/*"
for b in fix/mf-dotprofile-adopt-push fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-lib-relay \
         fix/mf-installer-relay fix/mf-audit-config fix/mf-audit-profile-json fix/mf-audit-consumers \
         feature/harness-rules-manifest feature/harness-cursor-user-rules feature/mf-config-no-machine \
         feature/harness-hookin feature/harness-mdm-followups; do
    nb="m-$(printf '%s' "$b" | tr '/' '-')"
    git checkout --quiet -B "$nb" src/main
    if git -c user.name=t -c user.email=t@t merge --quiet --no-edit "src/$b" > /dev/null 2>&1; then
        echo "### main + $b: merged"
        # apply-all.sh reads from the main checkout's object store; use this clone instead
        sed "s#^repo=.*#repo=$T/r#" "$S" > "$T/apply.sh"
        bash "$T/apply.sh" "$nb" "$D/edits-lib.txt" "$D/edits-entry.txt" "$D/edits-installer.txt" \
            "$D/edits-relay-prompt.txt" "$D/edits-harness.txt" "$D/edits-build.txt" "$D/edits-misc.txt" \
            | grep -E "FAIL|overall|times \(expected"
    else
        echo "### main + $b: MERGE CONFLICT (skipped)"
        git merge --abort > /dev/null 2>&1
    fi
done
