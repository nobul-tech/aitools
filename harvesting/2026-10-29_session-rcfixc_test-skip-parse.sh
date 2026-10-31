#!/usr/bin/env bash
# test-skip-parse.sh -- the L193a extraction on a real blog_warn line (bash 3.2)
set -euo pipefail
build_out=$(printf '[2026-10-26T00:00:00Z] [build-deploy] [info] Found 9 skill(s)\n\033[33m[2026-10-26T00:00:01Z] [build-deploy] [warn] No dotprofile found. Run '"'"'aitools user init'"'"' first -- skipping deploy build.\033[0m\n')
build_skip=$(grep -F -m 1 "skipping deploy build" <<< "$build_out") || build_skip=""
build_why=$(perl -pe 's/\e\[[0-9;]*m//g; s/^.*?\[warn\] //' <<< "$build_skip") || build_why="$build_skip"
printf 'skip=[%s]\n' "$build_why"
none_out="[x] [build-deploy] [ok] Rebuilt 40 scripts"
none_skip=$(grep -F -m 1 "skipping deploy build" <<< "$none_out") || none_skip=""
printf 'no-skip=[%s]\n' "$none_skip"
