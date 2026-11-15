#!/usr/bin/env bash
# syntax-all.sh -- bash -n and the pwsh parser on every touched script
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/console-profile
for f in scripts/setup-user-shell.sh scripts/aitools-install.sh tests/setup-user-shell/test-setup-user-shell.sh; do
    if bash -n "$WT/$f"; then echo "bash -n OK: $f"; else echo "bash -n FAIL: $f"; fi
done
pwsh -NoProfile -File "$WT/.scratch/session-M3-A/parse-check.ps1" \
    "$WT/scripts/setup-user-shell.ps1" "$WT/scripts/aitools-install.ps1" "$WT/tests/setup-user-shell/test-setup-user-shell.ps1"
echo "pwsh parser exit: $?"
