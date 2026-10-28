#!/usr/bin/env bash
# cv-p5.sh ROOT OUTDIR -- contract phase P5: local edits, pty run answering s (P5),
# then a pty run answering x (P5x) with two later items removed beforehand, to show
# that nothing after the abort is written.
set -uo pipefail
SCRATCH="/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh"
ROOT="${1:?ROOT}"; OUTDIR="${2:?OUTDIR}"; H="$ROOT/home"; GEN="$SCRATCH/cvgen.pl"
case "$ROOT" in "$SCRATCH"/*) ;; *) echo "ROOT not under scratch" >&2; exit 3 ;; esac
[ "$H" != "/Users/new-jose" ] || exit 3

O="$OUTDIR/P5"; mkdir -p "$O"; : > "$O/exit.txt"
L0=$(perl -ne 'END { print $. + 0 }' "$H/.aitools/logs/deploy.log")
printf 'P5 local edit (rule).\n' >> "$H/.cursor/rules/fx-shared.mdc"
printf 'P5 local edit (skill).\n' >> "$H/.cursor/skills/fx-skill-b/SKILL.md"
perl "$GEN" snap "$H" "$O/snap-before.txt"
python3 "$SCRATCH/cv-pty.py" "$ROOT" "$O" s
perl "$GEN" snap "$H" "$O/snap-after.txt"
perl "$GEN" tree "$H" "$O/tree.txt"
perl "$GEN" bakdirs "$H" "$O/bakdirs.txt"
perl "$GEN" rows "$O/rows.txt" "$O/cursor.summary"
perl -ne "print if \$. > $L0" "$H/.aitools/logs/deploy.log" > "$O/deploy.log.copy"
grep -c 'P5 local edit (rule).' "$H/.cursor/rules/fx-shared.mdc" > "$O/edit-rule-survived.txt"
grep -c 'P5 local edit (skill).' "$H/.cursor/skills/fx-skill-b/SKILL.md" > "$O/edit-skill-survived.txt"

X="$OUTDIR/P5x"; mkdir -p "$X"; : > "$X/exit.txt"
L1=$(perl -ne 'END { print $. + 0 }' "$H/.aitools/logs/deploy.log")
# later items: git-safety.mdc sorts after fx-shared.mdc in the rules loop; the skills step runs after the rules step
mv "$H/.cursor/rules/git-safety.mdc" "$X/git-safety.mdc.moved"
mv "$H/.cursor/skills/fx-skill-a/SKILL.md" "$X/fx-skill-a-SKILL.md.moved"
perl "$GEN" snap "$H" "$X/snap-before.txt"
python3 "$SCRATCH/cv-pty.py" "$ROOT" "$X" x
perl "$GEN" snap "$H" "$X/snap-after.txt"
perl "$GEN" tree "$H" "$X/tree.txt"
perl "$GEN" rows "$X/rows.txt" "$X/cursor.summary"
perl -ne "print if \$. > $L1" "$H/.aitools/logs/deploy.log" > "$X/deploy.log.copy"
for p in "$H/.cursor/rules/git-safety.mdc" "$H/.cursor/skills/fx-skill-a/SKILL.md"; do
    if [ -e "$p" ]; then echo "present (WRITTEN after abort): $p"; else echo "absent (not written): $p"; fi
done > "$X/later-items.txt"
# restore the two moved files so the fixture matches the other platform's after P5
mv "$X/git-safety.mdc.moved" "$H/.cursor/rules/git-safety.mdc"
mv "$X/fx-skill-a-SKILL.md.moved" "$H/.cursor/skills/fx-skill-a/SKILL.md"
perl "$GEN" tree "$H" "$X/tree-restored.txt"
