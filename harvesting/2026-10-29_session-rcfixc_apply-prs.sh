#!/usr/bin/env bash
# apply-prs.sh -- apply each main draft file to every open PR head that touches the
# same files; print only the apply verdict lines.
set -uo pipefail
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Fix-drafts/code
S=/Users/new-jose/repos/aitools/.scratch/session-rcfixc/apply-all.sh
for b in fix/mf-dotprofile-adopt-push fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-lib-relay \
         fix/mf-installer-relay fix/mf-audit-config fix/mf-audit-profile-json fix/mf-audit-consumers \
         feature/harness-rules-manifest feature/harness-cursor-user-rules feature/mf-config-no-machine; do
    echo "### origin/$b"
    bash "$S" "origin/$b" "$D/edits-lib.txt" "$D/edits-entry.txt" "$D/edits-installer.txt" \
        "$D/edits-relay-prompt.txt" "$D/edits-harness.txt" "$D/edits-build.txt" "$D/edits-misc.txt" \
        | grep -E "FAIL|overall|found .* times"
done
