#!/usr/bin/env bash
# commit-onto-origin.sh -- commit files onto origin/main and push, without touching
# the main checkout's branch, index or other agents' unpushed commits (scratch).
# Usage: commit-onto-origin.sh <msg-file> <repo-path>=<source-file> [...]
set -euo pipefail
R=/Users/new-jose/repos/aitools
msg="$1"; shift
git -C "$R" fetch origin --quiet
base=$(git -C "$R" rev-parse origin/main)
idx=$(mktemp)
export GIT_INDEX_FILE="$idx"
git -C "$R" read-tree "$base"
for spec in "$@"; do
  dest=${spec%%=*}; src=${spec#*=}
  blob=$(git -C "$R" hash-object -w "$src")
  # Mode follows the source: executable files and *.sh are 100755 (pre-commit
  # step 6), everything else 100644.
  mode=100644
  if [ -x "$src" ]; then mode=100755; fi
  case "$dest" in *.sh) mode=100755 ;; esac
  git -C "$R" update-index --add --cacheinfo "$mode,$blob,$dest"
done
tree=$(git -C "$R" write-tree)
unset GIT_INDEX_FILE
rm -f "$idx"
commit=$(git -C "$R" commit-tree "$tree" -p "$base" -F "$msg")
git -C "$R" push origin "$commit:refs/heads/main"
echo "pushed $commit onto $base"
