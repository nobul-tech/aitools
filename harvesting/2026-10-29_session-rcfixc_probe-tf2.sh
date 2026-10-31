#!/usr/bin/env bash
# probe-tf2.sh DIR -- run DIR/p2.ps1 (statement-terminating error inside try/finally)
set -uo pipefail
d="$1"
for m in bind net; do
    out=$(pwsh -NoProfile -File "$d/p2.ps1" -Mode "$m" 2>&1)
    rc=$?
    printf 'mode=%s rc=%s lines=%s\n' "$m" "$rc" "$(printf '%s' "$out" | grep -v -e '^\s*$' | grep -e start -e after -e finally | tr '\n' '|')"
done
