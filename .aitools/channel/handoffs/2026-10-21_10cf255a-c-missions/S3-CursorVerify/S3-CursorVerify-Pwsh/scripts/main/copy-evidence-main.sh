#!/usr/bin/env bash
# copy-evidence-main.sh -- copy the 207f1a6 rerun outputs (out-main) and the retargeted
# runners (main/) into the tracked hand-back folder; every .sh there gets the executable bit
set -euo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
B=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify/S3-CursorVerify-Pwsh
mkdir -p "$B/out-main" "$B/scripts/main"
for f in "$S"/main/*.sh; do cp "$f" "$B/scripts/main/"; done
cp "$S/make-main.sh" "$B/scripts/make-main.sh"
for d in "$S"/out-main/*/; do
    p=$(basename "$d")
    mkdir -p "$B/out-main/$p"
    for f in tree.txt tree-ext.txt rows.txt exit.txt harness.summary cursor.summary harness.out cursor.out pty-drive.txt check-p1.txt harness-copy.diff; do
        if [ -f "$d$f" ]; then cp "$d$f" "$B/out-main/$p/$f"; fi
    done
done
cp "$S/out-main/P5-prep-sha.txt" "$S/out-main/compare.txt" "$B/out-main/"
cp "$S/rerun-all.log" "$B/out-main/rerun-all.txt"
find "$B" -type f -name '*.sh' -exec chmod 755 {} +
echo "non-executable .sh files in the hand-back folder:"
find "$B" -type f -name '*.sh' ! -perm -u+x
echo "(end)"
find "$B" -type f | wc -l
du -sh "$B"
