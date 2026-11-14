#!/usr/bin/env bash
# watch-summary.sh <summary file>: print each new line; exit after the "done" line
f="$1"
n=0
while true; do
    if [ -f "$f" ]; then
        c=$(wc -l < "$f")
        if [ "$c" -gt "$n" ]; then
            sed -n "$((n + 1)),${c}p" "$f"
            n=$c
        fi
        if grep -q '^done ' "$f"; then
            break
        fi
    fi
    sleep 5
done
