#!/usr/bin/env bash
# commit-mission.sh MSGFILE -- copy the orchestrator's fixture scripts into the
# S3-CursorVerify mission folder, then commit every file in that folder onto
# origin/main through the shared commit-onto-origin.sh (channel exception).
set -euo pipefail
R=/Users/new-jose/repos/aitools
REL=.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify
M="$R/$REL"
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cverify
mkdir -p "$M/scripts"
for f in build-fixture.sh smoke-sh.sh wait-123.sh wait-123b.sh commit-mission.sh; do
    if [ -f "$S/$f" ]; then cp "$S/$f" "$M/scripts/$f"; fi
done
specs=()
while IFS= read -r -d '' f; do
    specs+=("$REL/${f#"$M"/}=$f")
done < <(find "$M" -type f -print0)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [commit-mission] [info] ${#specs[@]} files"
bash "$R/.scratch/session-10cf255a-c/commit-onto-origin.sh" "$1" "${specs[@]}"
