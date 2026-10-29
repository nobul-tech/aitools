#!/usr/bin/env bash
# p4-prep.sh -- S3-CursorVerify-Pwsh P4: the "user" edits ~/.cursor/rules/fx-retire2.mdc
# in the isolated HOME, then the fixture retires fx-retire, fx-retire2, fx-retire-skill
set -euo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
H="$S/fx-main/home"
case "$H" in /Users/new-jose|/Users/new-jose/) echo "real HOME" >&2; exit 1 ;; esac
printf '%s\n' "User edit: keep this rule." >> "$H/.cursor/rules/fx-retire2.mdc"
tail -3 "$H/.cursor/rules/fx-retire2.mdc"
bash /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cverify/build-fixture.sh retire "$S/fx-main"
git -C "$S/fx-main/aitools" log --oneline -1
