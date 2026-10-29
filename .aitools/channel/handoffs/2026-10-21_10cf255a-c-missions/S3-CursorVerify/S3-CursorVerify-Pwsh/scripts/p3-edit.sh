#!/usr/bin/env bash
# p3-edit.sh -- S3-CursorVerify-Pwsh P3: commit an edit to shared/rules/fx-shared.md
# and shared/skills/fx-skill-a/SKILL.md in the fixture clone (never the source repo)
set -euo pipefail
A=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx/aitools
printf '%s\n' "" "P3 edit: added line." >> "$A/shared/rules/fx-shared.md"
printf '%s\n' "" "P3 edit: added line." >> "$A/shared/skills/fx-skill-a/SKILL.md"
git -C "$A" -c user.name=S3-CursorVerify-Pwsh -c user.email=noreply@anthropic.com add shared/rules/fx-shared.md shared/skills/fx-skill-a/SKILL.md
git -C "$A" -c user.name=S3-CursorVerify-Pwsh -c user.email=noreply@anthropic.com commit --quiet -m "fixture P3: edit fx-shared and fx-skill-a"
git -C "$A" log --oneline -1
