#!/usr/bin/env bash
# For each "label|string|path" line on stdin, print the oldest origin/main commit that added the string.
set -euo pipefail
while IFS='|' read -r label str path; do
  [ -z "$label" ] && continue
  c=$(git -C /Users/new-jose/repos/aitools log --reverse --format='%h %ad %s' --date=short origin/main -S "$str" -- "$path" | sed -n '1p')
  printf '%s\t%s\n' "$label" "${c:-NONE}"
done
