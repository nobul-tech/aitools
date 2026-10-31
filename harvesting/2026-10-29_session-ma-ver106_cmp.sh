#!/usr/bin/env bash
# Compare main-side changes (merge-base..main parent) with head-vs-merge diffs for PR files.
set -euo pipefail
R=/Users/new-jose/repos/aitools
BASE=8a9dcb54558811235da5bb972613d374e3a124f7
MAINP=167dcbec7d70438df232fe4ca9de67303ea655ef
HEAD_=3de51d6c447e9002e9b5c2757a0dcbecfa5ac3bc
MERGE=4ca476f6bacd0acca76be174f48c8b7d084e4ee0
FILES="plans/tool-support-and-machine-profile.md reference/managed-file-deployment.md reference/tool-support-decision-tree.md scripts/aitools scripts/aitools.ps1"
for f in $FILES; do
  a=$(git -C "$R" diff "$BASE" "$MAINP" -- "$f" | git -C "$R" patch-id --stable | awk '{print $1}')
  b=$(git -C "$R" diff "$HEAD_" "$MERGE" -- "$f" | git -C "$R" patch-id --stable | awk '{print $1}')
  if [ "$a" = "$b" ]; then echo "SAME-PATCH $f"; else echo "DIFFERS $f main=$a headvsmerge=$b"; fi
done
# Also: does main-parent version of each PR file differ from base (i.e. did main touch it)?
for f in $FILES; do
  n=$(git -C "$R" log --oneline "$BASE..$MAINP" -- "$f" | wc -l | tr -d ' ')
  echo "main commits touching $f since base: $n"
done
# Conflict markers in merge result
git -C "$R" grep -n -E '^(<<<<<<<|>>>>>>>) ' "$MERGE" -- $FILES scripts/aitools-install.sh scripts/aitools-install.ps1 .claude/rules/interactive-menus.md || echo "no conflict markers"
# Is 4ca476f an ancestor of origin/main
git -C "$R" merge-base --is-ancestor "$MERGE" origin/main && echo "merge commit is ancestor of origin/main"
git -C "$R" rev-parse origin/main
