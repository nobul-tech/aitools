#!/usr/bin/env bash
# test-fd3-noninter.sh TMP -- the fd-3 copy, run without a terminal (stdin /dev/null),
# must still overwrite (non-interactive fallback unchanged).
set -euo pipefail
tmp="$1"
h="$tmp/home-ni"; l="$tmp/logs-ni"
rm -rf "$h" "$l"
mkdir -p "$h/.aitools/rules" "$h/.cursor/rules" "$l"
printf '{}\n' > "$h/.aitools/config.json"
printf '# Rule x\n\nfrom the harness\n' > "$h/.aitools/rules/x.md"
printf -- '---\nalwaysApply: true\n---\n# Rule x\n\nLOCAL EDIT\n' > "$h/.cursor/rules/x.mdc"
rc=0
env HOME="$h" AITOOLS_LOG_DIR="$l" AITOOLS_SUMMARY_FILE="$l/summary" bash "$tmp/scripts-fixed/setup-user-cursor.sh" < /dev/null > "$tmp/run-ni.txt" 2>&1 || rc=$?
echo "rc=$rc"
grep -c 'LOCAL EDIT' "$h/.cursor/rules/x.mdc" || true
grep -E 'cursor rules' "$l/summary" || true
