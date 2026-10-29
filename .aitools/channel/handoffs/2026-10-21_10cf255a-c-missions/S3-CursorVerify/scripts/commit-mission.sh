#!/usr/bin/env bash
# commit-mission.sh MSGFILE -- copy the orchestrator's fixture scripts into the
# S3-CursorVerify mission folder, then commit every file in that folder onto
# origin/main through a temporary index (channel exception). Mode: 100755 for
# *.sh, else 100644
# (v1 wrote every file at 100644 and broke check-pre-commit step 6).
set -euo pipefail
R=/Users/new-jose/repos/aitools
REL=.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify
M="$R/$REL"
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cverify
mkdir -p "$M/scripts"
for f in build-fixture.sh smoke-sh.sh wait-123.sh wait-123b.sh commit-mission.sh fix-modes.sh; do
    if [ -f "$S/$f" ]; then cp "$S/$f" "$M/scripts/$f"; chmod +x "$M/scripts/$f"; fi
done
git -C "$R" fetch origin --quiet
base=$(git -C "$R" rev-parse origin/main)
idx=$(mktemp)
export GIT_INDEX_FILE="$idx"
git -C "$R" read-tree "$base"
n=0
while IFS= read -r -d '' f; do
    mode=100644
    case "$f" in *.sh) mode=100755 ;; esac
    blob=$(git -C "$R" hash-object -w "$f")
    git -C "$R" update-index --add --cacheinfo "$mode,$blob,$REL/${f#"$M"/}"
    n=$((n+1))
done < <(find "$M" -type f -print0)
tree=$(git -C "$R" write-tree)
unset GIT_INDEX_FILE
rm -f "$idx"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [commit-mission] [info] $n files"
git -C "$R" diff-tree -r --stat "$base" "$tree"
commit=$(git -C "$R" commit-tree "$tree" -p "$base" -F "$1")
git -C "$R" push origin "$commit:refs/heads/main"
echo "pushed $commit onto $base"
