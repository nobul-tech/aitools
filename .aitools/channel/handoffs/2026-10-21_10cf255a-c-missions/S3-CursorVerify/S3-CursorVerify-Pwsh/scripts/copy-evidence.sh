#!/usr/bin/env bash
# copy-evidence.sh -- copy the S3-CursorVerify-Pwsh runners, generators and per-phase
# outputs (small files) from scratch into the tracked hand-back folder
set -euo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
B=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify/S3-CursorVerify-Pwsh
mkdir -p "$B/scripts" "$B/out"
for f in gen-tree.pl gen-rows.pl run-phase.sh check-p1.sh check-sources.sh p3-edit.sh p4-prep.sh p5.sh pty-drive.py p6x-retire-br.sh p7x-br-update.sh p8x-upper-retire.sh copy-evidence.sh; do
    cp "$S/$f" "$B/scripts/$f"
done
for d in "$S"/out/*/; do
    p=$(basename "$d")
    mkdir -p "$B/out/$p"
    for f in tree.txt tree-ext.txt rows.txt exit.txt harness.summary cursor.summary harness.out cursor.out pty-drive.txt check-p1.txt harness-copy.diff; do
        if [ -f "$d$f" ]; then cp "$d$f" "$B/out/$p/$f"; fi
    done
done
cp "$S/out/P5-prep-sha.txt" "$B/out/P5-prep-sha.txt"
find "$B" -type f | wc -l
du -sh "$B"
