#!/usr/bin/env bash
# p7x-br-update.sh restore|edit -- S3-CursorVerify-Pwsh extra variant for bracket names:
#   restore: bring back shared/rules/fx-[br].md and shared/skills/fx-[br]ack (as at build), commit
#   edit   : append a line to both, commit (the next run must update them)
set -euo pipefail
A=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx/aitools
g() { git -C "$A" -c user.name=S3-CursorVerify-Pwsh -c user.email=noreply@anthropic.com "$@"; }
case "${1:?restore|edit}" in
    restore)
        g checkout HEAD~1 -- ':(literal)shared/rules/fx-[br].md' ':(literal)shared/skills/fx-[br]ack'
        g commit --quiet -m "fixture X: restore fx-[br].md and fx-[br]ack"
        ;;
    edit)
        printf '%s\n' "" "PX edit: bracket update." >> "$A/shared/rules/fx-[br].md"
        printf '%s\n' "" "PX edit: bracket update." >> "$A/shared/skills/fx-[br]ack/SKILL.md"
        g add -- ':(literal)shared/rules/fx-[br].md' ':(literal)shared/skills/fx-[br]ack/SKILL.md'
        g commit --quiet -m "fixture X: edit fx-[br].md and fx-[br]ack"
        ;;
esac
g log --oneline -1
g ls-files -- ':(literal)shared/rules/fx-[br].md' ':(literal)shared/skills/fx-[br]ack'
