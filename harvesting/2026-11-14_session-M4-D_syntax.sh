#!/usr/bin/env bash
# Syntax checks for the M4-D-Wire edits.
set -uo pipefail
WT=C:/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
S=$WT/.scratch/session-M4-D
for f in scripts/aitools-install.sh scripts/build-deploy.sh scripts/setup-pywinpty.sh; do
    if bash -n "$WT/$f"; then echo "bash -n OK: $f"; else echo "bash -n FAIL ($?): $f"; fi
done
pwsh -NoProfile -File "$S/parse.ps1" "$WT/scripts/aitools-install.ps1"
echo "parse exit: $?"
