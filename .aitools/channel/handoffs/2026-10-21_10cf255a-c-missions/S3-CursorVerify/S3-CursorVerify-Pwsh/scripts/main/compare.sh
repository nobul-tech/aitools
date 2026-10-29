#!/usr/bin/env bash
# compare.sh -- diff out-main (207f1a6) against out (9c2d025) per phase, plus the
# in-run checks (P1->P2 and P2->P3 snapshots, P1 content checks, P4/P5 key lines)
set -uo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
for p in P0 P1 P2 P3 P3b P4 P5-s P5-x PX-br PX-br-restore PX-br-update PX-upper; do
    for f in tree.txt tree-ext.txt rows.txt exit.txt; do
        [ -f "$S/out/$p/$f" ] || continue
        if diff "$S/out/$p/$f" "$S/out-main/$p/$f" > /dev/null; then
            echo "SAME  $p/$f"
        else
            echo "DIFF  $p/$f"; diff "$S/out/$p/$f" "$S/out-main/$p/$f"
        fi
    done
done
echo "== check-p1 (old vs new, paths normalized)"
perl -pe 's{session-cv-ps/fx/}{session-cv-ps/FX/}g; s{ Oct 2\d \d\d:\d\d }{ DATE }g' "$S/out/P1/check-p1.txt" > "$S/out-main/P1/check-p1.old.tmp"
perl -pe 's{session-cv-ps/fx-main/}{session-cv-ps/FX/}g; s{ Oct 2\d \d\d:\d\d }{ DATE }g' "$S/out-main/P1/check-p1.txt" > "$S/out-main/P1/check-p1.new.tmp"
diff "$S/out-main/P1/check-p1.old.tmp" "$S/out-main/P1/check-p1.new.tmp" | grep -v -E '^[<>] .*(user-own|user-skill).*1793' || echo "check-p1: same apart from user-file mtimes"
echo "== snapshot P1->P2 (new run)"
diff "$S/out-main/P1/snap.txt" "$S/out-main/P2/snap.txt" | cut -c1-80
echo "== snapshot P2->P3 dry run (new run; expect empty)"
diff "$S/out-main/P2/snap.txt" "$S/out-main/P3/snap.txt"
echo "== user files P0 vs P4 (new run)"
grep -E 'user-own|user-skill' "$S/out-main/P0/snap.txt" > "$S/out-main/P0/user.tmp"
grep -E 'user-own|user-skill' "$S/out-main/P4/snap.txt" > "$S/out-main/P4/user.tmp"
diff "$S/out-main/P0/user.tmp" "$S/out-main/P4/user.tmp" && echo "user files identical P0..P4"
echo "== key lines (new run)"
grep -h -E "Removed fx-retire|Backup-Dir|line ignored|Preserved: .*FX-Upper" "$S/out-main/P4/cursor.out" "$S/out-main/PX-upper/harness.out" "$S/fx-main/home/.aitools/logs/deploy.log" | perl -pe 's{^\S+ }{}' | sort | uniq -c
grep -h -E "Aborted by user" "$S/out-main/P5-x/cursor.out"
grep -h -E "^\.(cursor|aitools)/skills/fx-skill-a/scripts/run.sh" "$S/out-main/P1/tree.txt"
