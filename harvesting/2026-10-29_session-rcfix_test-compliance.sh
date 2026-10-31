#!/usr/bin/env bash
# test-compliance.sh TMP -- run the fixed check-script-compliance.sh in the throwaway clone (isolated HOME).
set -euo pipefail
tmp="$1"
export HOME="$tmp/home" AITOOLS_LOG_DIR="$tmp/logs"
rc=0
(cd "$tmp/clone" && bash scripts/check-script-compliance.sh) > "$tmp/E.txt" 2>&1 || rc=$?
echo "rc=$rc"
grep -E '12\. write_summary|SUMMARY' "$tmp/E.txt"
