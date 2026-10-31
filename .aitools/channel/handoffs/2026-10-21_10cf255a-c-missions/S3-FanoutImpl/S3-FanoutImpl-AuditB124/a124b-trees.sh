#!/usr/bin/env bash
# a124b-trees.sh RUNS case... -- sh vs ps ~/.claude/skills* tree (modes) per case
set -uo pipefail
R="$1"; shift
for c in "$@"; do
    d="$R/$c"
    if cmp -s "$d/sh.tree" "$d/ps.tree"; then echo "== $c tree: same"; else echo "== $c tree: DIFFER"; diff "$d/sh.tree" "$d/ps.tree"; fi
done
for c in "$@"; do echo "-- $c sh.tree"; cat "$R/$c/sh.tree"; done
