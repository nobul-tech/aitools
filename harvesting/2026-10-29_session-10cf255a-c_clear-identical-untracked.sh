#!/usr/bin/env bash
# clear-identical-untracked.sh -- delete untracked files in the main checkout that are
# byte-identical to the same path on origin/main (copies left by commit-onto-origin.sh),
# so `git pull --ff-only` can run. Leaves every other untracked file alone. (scratch)
set -euo pipefail
R=/Users/new-jose/repos/aitools
git -C "$R" fetch origin --quiet
git -C "$R" ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
  remote=$(git -C "$R" rev-parse --verify --quiet "origin/main:$f" || true)
  [ -n "$remote" ] || continue
  local_hash=$(git -C "$R" hash-object "$R/$f")
  if [ "$local_hash" = "$remote" ]; then
    rm -- "$R/$f"
    echo "removed identical: $f"
  else
    echo "KEPT (differs from origin/main): $f"
  fi
done
