#!/usr/bin/env bash
# p8x-upper-retire.sh -- S3-CursorVerify-Pwsh extra variant: remove FX-Upper.MD from the
# fixture dotprofile (commit there) to see whether it is retired downstream
set -euo pipefail
D=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx-main/dotprofile
git -C "$D" -c user.name=S3-CursorVerify-Pwsh -c user.email=noreply@anthropic.com rm --quiet -- claude/rules/FX-Upper.MD
git -C "$D" -c user.name=S3-CursorVerify-Pwsh -c user.email=noreply@anthropic.com commit --quiet -m "fixture X: remove FX-Upper.MD"
git -C "$D" log --oneline -1
