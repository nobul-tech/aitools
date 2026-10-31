#!/usr/bin/env bash
# Wait (max ~9 min) until local main has no commits that origin/main lacks.
set -euo pipefail
r=/Users/new-jose/repos/aitools
n=0
while [ "$n" -lt 54 ]; do
  git -C "$r" fetch -q origin
  ahead=$(git -C "$r" rev-list --count origin/main..main)
  if [ "$ahead" -eq 0 ]; then echo "clean: local main not ahead"; exit 0; fi
  sleep 10
  n=$((n+1))
done
echo "still ahead by $ahead"
git -C "$r" log --oneline origin/main..main
