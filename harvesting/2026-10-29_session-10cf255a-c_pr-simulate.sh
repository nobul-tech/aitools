#!/usr/bin/env bash
# pr-simulate.sh -- simulate merging PRs onto origin/main in a given order with merge
# commits (no checkout; merge-tree + commit-tree). Usage: pr-simulate.sh "<n:branch> ..."
set -euo pipefail
R=/Users/new-jose/repos/aitools
cur=$(git -C "$R" rev-parse origin/main)
for p in $1; do
  n=${p%%:*}; b=${p#*:}
  if git -C "$R" merge-tree --write-tree --name-only "$cur" "origin/$b" > /tmp/sim.$$ 2>&1; then
    tree=$(head -1 /tmp/sim.$$)
    cur=$(git -C "$R" commit-tree "$tree" -p "$cur" -p "origin/$b" -m "sim merge #$n")
    echo "#$n merges clean"
  else
    echo "#$n CONFLICT: $(tail -n +2 /tmp/sim.$$ | grep -v '^$' | grep -v '^Auto-merging' | tr '\n' ' ')"
    tree=$(head -1 /tmp/sim.$$)
  fi
done
rm -f /tmp/sim.$$
