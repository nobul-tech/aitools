#!/usr/bin/env bash
# probe-tty.sh -- can this shell open /dev/tty for writing?
if (printf '' > /dev/tty) 2>/dev/null; then echo "tty: writable"; else echo "tty: not writable"; fi
if [ -t 0 ]; then echo "stdin: terminal"; else echo "stdin: not a terminal"; fi
echo "bash: $BASH_VERSION"
