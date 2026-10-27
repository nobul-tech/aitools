#!/usr/bin/env bash
# test-fd3.sh TMP -- FX-3 test: on a pty, the main copy of setup-user-cursor.sh
# overwrites a locally edited ~/.cursor/rules/x.mdc without asking; the fd-3 copy
# shows the review menu, and [s]kip keeps the local edit. Isolated HOMEs only.
set -euo pipefail
tmp="$1"
S=/Users/new-jose/repos/aitools/.scratch/session-rcfix
rm -rf "$tmp/scripts-main" "$tmp/scripts-fixed"
cp -R "$tmp/main/scripts" "$tmp/scripts-main"
cp -R "$tmp/main/scripts" "$tmp/scripts-fixed"
cp "$tmp/out-origin_main/scripts/setup-user-cursor.sh" "$tmp/scripts-fixed/setup-user-cursor.sh"
/bin/bash -n "$tmp/scripts-fixed/setup-user-cursor.sh"
echo "bash 3.2 -n ok"
SH="${2:-bash}"
echo "shell: $SH"
for v in main fixed; do
    h="$tmp/home-$v"; l="$tmp/logs-$v"
    rm -rf "$h" "$l"
    mkdir -p "$h/.aitools/rules" "$h/.cursor/rules" "$l"
    printf '{}\n' > "$h/.aitools/config.json"
    printf '# Rule x\n\nfrom the harness\n' > "$h/.aitools/rules/x.md"
    printf -- '---\nalwaysApply: true\n---\n# Rule x\n\nLOCAL EDIT\n' > "$h/.cursor/rules/x.mdc"
    echo "== $v"
    expect "$S/fd3-run.exp" "$tmp/scripts-$v" "$h" "$l" "$SH" > "$tmp/run-$v.txt" 2>&1 || echo "expect rc=$?"
    grep -E 'REVIEWED=|TIMEOUT' "$tmp/run-$v.txt" || true
    grep -c 'LOCAL EDIT' "$h/.cursor/rules/x.mdc" || true
    grep -E 'cursor rules' "$l/summary" || true
    grep -h 'non-interactive' "$l"/*.log || true
done
