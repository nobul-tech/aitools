#!/usr/bin/env bash
# p6x-retire-br.sh -- S3-CursorVerify-Pwsh extra variant (after P5, not in the contract):
# retire the bracket-name sources shared/rules/fx-[br].md and shared/skills/fx-[br]ack
# in the fixture clone (a variant of build-fixture.sh retire; that script is not edited)
set -euo pipefail
A=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx/aitools
git -C "$A" -c user.name=S3-CursorVerify-Pwsh -c user.email=noreply@anthropic.com rm --quiet -r -- ':(literal)shared/rules/fx-[br].md' ':(literal)shared/skills/fx-[br]ack'
git -C "$A" -c user.name=S3-CursorVerify-Pwsh -c user.email=noreply@anthropic.com commit --quiet -m "fixture X: retire fx-[br].md and fx-[br]ack"
git -C "$A" log --oneline -1
git -C "$A" ls-files shared/rules shared/skills | grep -F '[br]' || echo "no [br] sources left"
