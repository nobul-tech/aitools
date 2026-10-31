#!/usr/bin/env bash
# verify-2.sh -- more evidence for #28 / #29 (read-only)
set -euo pipefail
R=/Users/new-jose/repos/aitools
printf -- '--- raw tty reads outside the lib helper\n'
git -C "$R" grep -nE "read -r? ?[A-Za-z_ ]+< ?/dev/tty" origin/main -- scripts shared/hooks | grep -v "aitools-lib.sh:15[78]" || printf '(none)\n'
printf -- '--- ReadLine().ToLower anywhere\n'
git -C "$R" grep -nE "ReadLine\(\)" origin/main -- scripts | grep -v "aitools-lib.ps1:15" || printf '(none)\n'
printf -- '--- commits naming #29\n'
git -C "$R" log origin/main --oneline -E --grep="#29\b|GitHub #29|issue 29|issue #29" | head -20
printf -- '--- commits naming #28\n'
git -C "$R" log origin/main --oneline -E --grep="#28\b|issue #28" | head -20
printf -- '--- scripts/aitools around lib source\n'
git -C "$R" show origin/main:scripts/aitools | sed -n '1538,1575p'
printf -- '--- scripts/aitools early log defs\n'
git -C "$R" show origin/main:scripts/aitools | grep -nE "^[a-z_]+\(\) *\{" | head -30
printf -- '--- script-standards-detail Logging overrides\n'
git -C "$R" show origin/main:reference/script-standards-detail.md | grep -nE -A12 "Logging override" | head -40
