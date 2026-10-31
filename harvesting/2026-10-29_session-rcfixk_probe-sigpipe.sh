#!/usr/bin/env bash
# probe-sigpipe.sh -- does `printf ... | head -N` abort under set -euo pipefail?
# Runs each pattern in a child bash with small and large input; prints rc.
set -uo pipefail
BASH_BIN="${1:-bash}"
for size in 100 200000 2000000; do
    for pat in loop assign; do
        if [ "$pat" = loop ]; then
            body='big=$(perl -e "print qq(line\n) x $N"); printf "%s\n" "$big" | head -30 | while IFS= read -r l; do :; done; echo reached'
        else
            body='big=$(perl -e "print qq(line\n) x $N"); x=$(printf "%s\n" "$big" | head -1); echo reached'
        fi
        out=$(N="$size" "$BASH_BIN" -c "set -euo pipefail; $body" 2>&1)
        rc=$?
        printf '%s lines=%s pattern=%s rc=%s out=%s\n' "$BASH_BIN" "$size" "$pat" "$rc" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-80)"
    done
done
