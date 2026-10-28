#!/usr/bin/env bash
# p5.sh prep|run-s|prep-x|run-x -- S3-CursorVerify-Pwsh P5 (pty review prompts)
#   prep   : local edits to ~/.cursor/rules/fx-shared.mdc and ~/.cursor/skills/fx-skill-b/SKILL.md
#   run-s  : setup-user-cursor (step4-driver) under a pty, answer "s" to every prompt -> out/P5-s
#   prep-x : delete two items that come AFTER fx-shared.mdc in deploy order
#            (~/.cursor/rules/web-sources.mdc, ~/.cursor/skills/tool-ops/SKILL.md) so a
#            write after the abort would show up
#   run-x  : the same under a pty answering "x" -> out/P5-x (expect exit 2)
set -uo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
ROOT="$S/fx"; A="$ROOT/aitools"; H="$ROOT/home"
case "$H" in /Users/new-jose|/Users/new-jose/) echo "real HOME" >&2; exit 1 ;; esac
case "$H" in "$S"/*) ;; *) echo "HOME not isolated" >&2; exit 1 ;; esac
mode="${1:?mode}"

pty_run() { # pty_run PHASE ANSWER
    local O="$S/out/$1"; mkdir -p "$O"
    : > "$O/cursor.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_LOG_DIR -u AITOOLS_USER_REPO_PATH \
        HOME="$H" USERPROFILE="$H" AITOOLS_SUMMARY_FILE="$O/cursor.summary" PATH="$S/bin:$PATH" NO_COLOR=1 TERM=dumb \
        python3 -I "$S/pty-drive.py" "$2" "$O/cursor.raw" -- \
        pwsh -NoProfile -File "$A/tests/rules-fanout-cursor/step4-driver.ps1" "$A/scripts/setup-user-cursor.ps1" \
        > "$O/pty-drive.txt" 2>&1
    local rc=$?
    echo "cursor $rc" > "$O/exit.txt"
    perl -pe 's/\e\[[0-9;?]*[A-Za-z]//g; s/\r//g' "$O/cursor.raw" > "$O/cursor.out"
    perl "$S/gen-rows.pl" "$O/rows.txt" "$O/cursor.summary"
    perl "$S/gen-tree.pl" "$H" "$O"
    cat "$O/pty-drive.txt"
    echo "exit $rc"
}

case "$mode" in
    prep)
        printf '%s\n' "Local edit P5 (rule)." >> "$H/.cursor/rules/fx-shared.mdc"
        printf '%s\n' "Local edit P5 (skill)." >> "$H/.cursor/skills/fx-skill-b/SKILL.md"
        shasum -a 256 "$H/.cursor/rules/fx-shared.mdc" "$H/.cursor/skills/fx-skill-b/SKILL.md" | tee "$S/out/P5-prep-sha.txt"
        ;;
    run-s) pty_run P5-s s ;;
    prep-x)
        mv "$H/.cursor/rules/web-sources.mdc" "$S/out/P5-moved-web-sources.mdc"
        mv "$H/.cursor/skills/tool-ops/SKILL.md" "$S/out/P5-moved-tool-ops-SKILL.md"
        ls "$H/.cursor/rules/web-sources.mdc" "$H/.cursor/skills/tool-ops/SKILL.md"
        ;;
    run-x) pty_run P5-x x ;;
    *) echo "unknown mode $mode" >&2; exit 64 ;;
esac
