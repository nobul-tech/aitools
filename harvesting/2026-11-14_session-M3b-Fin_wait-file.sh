#!/usr/bin/env bash
# Wait until a file contains a pattern, up to N seconds. Usage: wait-file.sh <file> <pattern> <seconds>
set -uo pipefail
f="$1"; pat="$2"; max="$3"
end=$(( $(date +%s) + max ))
until grep -qE "$pat" "$f" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$end" ]; then echo "TIMEOUT waiting for $pat"; exit 1; fi
    sleep 15
done
grep -E "$pat" "$f"
