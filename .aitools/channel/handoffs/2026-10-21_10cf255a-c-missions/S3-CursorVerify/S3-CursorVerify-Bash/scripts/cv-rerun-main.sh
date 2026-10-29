#!/usr/bin/env bash
# cv-rerun-main.sh -- rerun P1-P5 on fx-main (REF 207f1a6) into out-main, then P1 under /bin/bash 3.2 on fx32-main.
set -uo pipefail
S="/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh"
R="$S/fx-main"; O="$S/out-main"
for p in P1 P2 P3 P3b P4; do
    bash "$S/cv-phase.sh" "$R" "$O" "$p"
done
bash "$S/cv-check-p1.sh" "$R" "$O/P1"
bash "$S/cv-p5.sh" "$R" "$O"
bash "$S/cv-phase.sh" "$S/fx32-main" "$S/out-main-bash32" P1 /bin/bash
bash "$S/cv-check-p1.sh" "$S/fx32-main" "$S/out-main-bash32/P1"
# differences against the 9c2d025 run (tree.txt, rows.txt, exit.txt per phase)
for p in P1 P2 P3 P3b P4 P5 P5x; do
    for f in tree.txt rows.txt exit.txt; do
        if [ -f "$S/out/$p/$f" ]; then
            printf '== %s/%s\n' "$p" "$f"
            diff "$S/out/$p/$f" "$O/$p/$f"
        fi
    done
done > "$O/diff-vs-9c2d025.txt" 2>&1
for f in tree.txt rows.txt exit.txt; do
    printf '== P1-bash32/%s vs out-main/P1\n' "$f"
    diff "$O/P1/$f" "$S/out-main-bash32/P1/$f"
done >> "$O/diff-vs-9c2d025.txt" 2>&1
# the same assertions the 9c2d025 run reported
{
  echo "== P2 snapshot diff"; diff "$O/P2/snap-before.txt" "$O/P2/snap-after.txt"
  echo "== P3 snapshot diff"; diff "$O/P3/snap-before.txt" "$O/P3/snap-after.txt"
  echo "== P4 cursor WARN/ACTION rows"; grep -c -E '^(WARN|ACTION)' "$O/P4/cursor.summary"
  echo "== P4 fx-retire2 log"; grep -n 'fx-retire2' "$O/P4/deploy.log.copy"
  echo "== P5 prompts"; cat "$O/P5/prompts.txt"
  echo "== P5 edits survived"; cat "$O/P5/edit-rule-survived.txt" "$O/P5/edit-skill-survived.txt"
  echo "== P5x"; cat "$O/P5x/exit.txt" "$O/P5x/later-items.txt"
  echo "== P5x restored vs P5"; diff "$O/P5/tree.txt" "$O/P5x/tree-restored.txt"
  echo "== shell errors"; grep -n -E 'line [0-9]+:|unbound|bad substitution|command not found|syntax error' "$O"/*/harness.out "$O"/*/cursor.out "$S/out-main-bash32/P1/"*.out
  echo "== end"
} > "$O/assertions.txt" 2>&1
echo done
