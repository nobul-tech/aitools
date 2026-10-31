#!/usr/bin/env bash
# pathrefs-branches.sh -- run a patched check-path-refs.py (arg 1) against a
# full git-archive export of each open PR branch (outside the repo); report
# new dead references vs the branch's own checker.
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
CHK="$1"
for b in feature/mf-config-no-machine feature/harness-rules-manifest docs/mf-incidents fix/mf-dotprofile-adopt-push docs/mf-audit feature/harness-hookin fix/mf-audit-profile-json fix/mf-audit-consumers feature/harness-cursor-user-rules feature/harness-mdm-followups fix/mf-audit-claude-build fix/mf-lib-runner-result fix/mf-audit-config fix/mf-lib-relay fix/mf-installer-relay docs/m3-lead-plan; do
    E="$(mktemp -d)"
    git -C "$REPO" archive "origin/$b" | tar -x -C "$E"
    git -C "$E" init -q
    own=$(python3 "$E/scripts/check-path-refs.py" --root "$E" --quiet 2>&1 | tail -1)
    cp "$CHK" "$E/scripts/check-path-refs.py"
    new=$(python3 "$E/scripts/check-path-refs.py" --root "$E" 2>&1)
    printf '== %s | own checker: %s | patched: %s\n' "$b" "$own" "$(printf '%s\n' "$new" | tail -1)"
    printf '%s\n' "$new" | grep -v '^dead path references' | sed 's/^/     /'
    rm -rf "$E"
done
