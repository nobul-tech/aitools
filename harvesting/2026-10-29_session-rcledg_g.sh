#!/usr/bin/env bash
# git grep on origin/main: g.sh <pattern> [pathspec...]
set -euo pipefail
pat="$1"; shift
git -C /Users/new-jose/repos/aitools grep -n -E -e "$pat" origin/main -- "$@" || printf 'NO MATCH: %s in %s\n' "$pat" "$*"
