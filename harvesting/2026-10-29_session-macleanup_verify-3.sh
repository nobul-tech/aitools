#!/usr/bin/env bash
# verify-3.sh -- relay-outbound read, PS1 twin, #28 commit and tests (read-only)
set -euo pipefail
R=/Users/new-jose/repos/aitools
printf -- '--- relay-outbound-prompt.sh 60-95\n'
git -C "$R" show origin/main:scripts/relay-outbound-prompt.sh | sed -n '1,12p'
git -C "$R" show origin/main:scripts/relay-outbound-prompt.sh | sed -n '60,95p'
printf -- '--- relay-outbound-prompt.ps1 ReadLine/Read-Host\n'
git -C "$R" grep -nE "ReadLine|Read-Host|ToLower" origin/main -- scripts/relay-outbound-prompt.ps1 || printf '(none)\n'
printf -- '--- #28 commits introducing _pre_lib_warnings\n'
git -C "$R" log origin/main --format='%h %ad %s' --date=short -S"_pre_lib_warnings" -- scripts/aitools | tail -3
printf -- '--- tests/logging entry point check\n'
git -C "$R" grep -nE "define no log|no log function|entry point" origin/main -- tests/logging | head -10
printf -- '--- PS1 aitools.ps1 function defs Log*\n'
git -C "$R" grep -nE "^\s*function (Log|LogOk|LogError|LogWarn)\s*\{?" origin/main -- scripts/aitools.ps1 scripts/aitools || printf '(none)\n'
printf -- '--- JSON field review EOF test\n'
git -C "$R" grep -nE "EOF" origin/main -- tests | head -20
