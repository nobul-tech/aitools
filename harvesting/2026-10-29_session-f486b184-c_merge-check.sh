#!/usr/bin/env bash
# merge-check.sh BRANCH... -- per branch vs origin/main: merge-base count and
# whether a dry-run merge is clean (git merge-tree exit code)
set -uo pipefail
repo=/Users/new-jose/repos/aitools
for b in "$@"; do
    bases=$(git -C "$repo" merge-base --all origin/main "origin/$b" | tr '\n' ' ')
    n=$(printf '%s' "$bases" | wc -w | tr -d ' ')
    if git -C "$repo" merge-tree --write-tree --name-only origin/main "origin/$b" > /dev/null; then
        clean=clean
    else
        clean=CONFLICT
    fi
    printf '%-34s bases=%s [%s] dry-run=%s\n' "$b" "$n" "$bases" "$clean"
done
