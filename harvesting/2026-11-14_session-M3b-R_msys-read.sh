#!/usr/bin/env bash
# Same read as read_tty_choice in scripts/aitools-lib.sh: IFS= read -r < /dev/tty
set -euo pipefail
out="$1"
x=""
rc=0
IFS= read -r x < /dev/tty || rc=$?   # rc recorded below (EOF/failure is the datum)
printf '%s MSYS GOT[%s] rc=%s stdin-tty=%s\n' "$(date +%H:%M:%S.%3N)" "$x" "$rc" "$([ -t 0 ] && echo yes || echo no)" >> "$out"
