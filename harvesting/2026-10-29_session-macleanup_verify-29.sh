#!/usr/bin/env bash
# verify-29.sh -- deeper evidence for issue #29 (EOF at prompts), plus #28 and #31 context
set -euo pipefail
R=/Users/new-jose/repos/aitools
g() { printf '\n--- %s\n' "$*"; git -C "$R" grep -n "$@" || printf '(no match)\n'; }
g -E "< /dev/tty" origin/main -- scripts/aitools-lib.sh
g -E "read_tty_choice" origin/main -- scripts
g -E "ReadLine\(\)" origin/main -- scripts/aitools-lib.ps1
g -E "Read-ConsoleChoice" origin/main -- scripts
g -E "EOF" origin/main -- tests/managed-files/test-managed-files.sh
printf '\n--- aitools-lib.sh read_tty_choice body\n'
git -C "$R" show origin/main:scripts/aitools-lib.sh | sed -n '1570,1600p'
printf '\n--- aitools-lib.ps1 Read-ConsoleChoice body\n'
git -C "$R" show origin/main:scripts/aitools-lib.ps1 | sed -n '1500,1535p'
printf '\n--- #28 scripts/aitools overrides\n'
git -C "$R" grep -nE "^ *(log|log_error|log_warn|log_ok)\(\) *\{|aitools-lib.sh\"" origin/main -- scripts/aitools || printf '(no match)\n'
git -C "$R" grep -nE "^function (Log|LogError|LogWarn)\b|aitools-lib.ps1\"|Initialize-Logging \"aitools\"" origin/main -- scripts/aitools.ps1 || printf '(no match)\n'
printf '\n--- #31 sync_managed_json missing live file\n'
git -C "$R" grep -nE "does not exist|not exist yet|creat(e|ing) .*settings.json|no settings.json" origin/main -- scripts/aitools-lib.sh scripts/setup-user-settings.sh || printf '(no match)\n'
