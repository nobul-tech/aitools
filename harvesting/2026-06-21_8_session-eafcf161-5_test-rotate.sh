#!/usr/bin/env bash
set -uo pipefail
source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
T="/tmp/aitools-rottest-bash"
rm -rf "$T"
mkdir -p "$T"
AITOOLS_LOG_DIR="$T"

mk6mb() { dd if=/dev/zero of="$1" bs=1048576 count=6 2>/dev/null; }

mk6mb "$T/deploy.log"
logging_init "rot-test"
echo "after 1st rotate: $(ls "$T" | sort | tr '\n' ' ')"

mk6mb "$T/deploy.log"
logging_init "rot-test"
echo "after 2nd rotate: $(ls "$T" | sort | tr '\n' ' ')"

rm -f "$T"/deploy.log*
echo "small" > "$T/deploy.log"
logging_init "rot-test"
echo "small (expect no .1): $(ls "$T" | sort | tr '\n' ' ')"

rm -rf "$T"
