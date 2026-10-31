#!/usr/bin/env bash
# probe-tf.sh DIR -- run DIR/p1.ps1 under pwsh -File in each mode, print the exit code
set -uo pipefail
d="$1"
for m in throw cmdlet noeap; do
    out=$(pwsh -NoProfile -File "$d/p1.ps1" -Mode "$m" 2>&1)
    rc=$?
    printf 'mode=%s rc=%s out=%s\n' "$m" "$rc" "$(printf '%s' "$out" | tr '\n' '|' | cut -c1-160)"
done
