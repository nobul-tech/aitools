#!/usr/bin/env bash
# termios mechanism check (Cygwin/MSYS termios emulation, NOT a Linux/macOS kernel tty):
# a previous program left the tty raw (stty raw -echo), then
#   plain   : read_tty_choice's current read (IFS= read -r < /dev/tty)
#   guarded : prototype -- save stty -g, force icanon echo icrnl, read, restore
set -euo pipefail
out="$1"
variant="$2"
ts() { date +%H:%M:%S.%3N; }
orig=$(stty -g < /dev/tty)
stty raw -echo < /dev/tty   # simulate a child that exited without restoring
raw=$(stty -g < /dev/tty)
printf '%s STTY left raw: %s\n' "$(ts)" "$raw" >> "$out"
printf '%s BASH-READY\n' "$(ts)" >> "$out"
x=""
rc=0
if [ "$variant" = "guarded" ]; then
    saved=$(stty -g < /dev/tty) || saved=""   # empty = cannot query: read as before
    if [ -n "$saved" ]; then stty icanon echo icrnl < /dev/tty; fi
    IFS= read -r x < /dev/tty || rc=$?
    if [ -n "$saved" ]; then stty "$saved" < /dev/tty; fi
else
    IFS= read -r x < /dev/tty || rc=$?
fi
after=$(stty -g < /dev/tty)
printf '%s BASH GOT[%s] rc=%s; stty after read %s raw state\n' "$(ts)" "$(printf '%s' "$x" | od -An -c | tr -s ' ')" "$rc" "$([ "$after" = "$raw" ] && echo equals || echo differs-from)" >> "$out"
stty "$orig" < /dev/tty
