#!/usr/bin/env bash
# wait-suites.sh -- wait (max 9 min) until run-suites.sh has printed all 6 result lines
set -uo pipefail
OUT="C:/Users/jdpal/AppData/Local/Temp/claude/89ee379d6ae34d53/87795dc3-e9b0-4f82-937b-139b3f13fa81/tasks/bzgnh30wg.output"
n=0
until [ "$(grep -c 'rc=' "$OUT")" -ge 6 ]; do
    n=$((n + 1))
    if [ "$n" -gt 540 ]; then echo "timeout"; break; fi
    sleep 1
done
cat "$OUT"
