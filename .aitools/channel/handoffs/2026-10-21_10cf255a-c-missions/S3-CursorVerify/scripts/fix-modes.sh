#!/usr/bin/env bash
# fix-modes.sh MSGFILE -- set 100755 on every .sh under the S3-CursorVerify
# mission folder on origin/main via a temporary index; commit onto origin/main, push.
set -euo pipefail
R=/Users/new-jose/repos/aitools
REL=.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify
git -C "$R" fetch origin --quiet
base=$(git -C "$R" rev-parse origin/main)
idx=$(mktemp)
export GIT_INDEX_FILE="$idx"
git -C "$R" read-tree "$base"
n=0
while IFS= read -r p; do
    case "$p" in *.sh) git -C "$R" update-index --chmod=+x -- "$p"; n=$((n+1)) ;; esac
done < <(git -C "$R" ls-tree -r --name-only "$base" -- "$REL")
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [fix-modes] [info] chmod +x on $n files"
tree=$(git -C "$R" write-tree)
unset GIT_INDEX_FILE
rm -f "$idx"
git -C "$R" diff-tree -r --summary "$base" "$tree" | grep -c "mode change" || echo "0 mode changes"
commit=$(git -C "$R" commit-tree "$tree" -p "$base" -F "$1")
git -C "$R" push origin "$commit:refs/heads/main"
echo "pushed $commit onto $base"
