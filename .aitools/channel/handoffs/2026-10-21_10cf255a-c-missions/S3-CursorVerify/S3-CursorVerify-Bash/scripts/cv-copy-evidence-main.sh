#!/usr/bin/env bash
# cv-copy-evidence-main.sh -- copy the REF 207f1a6 rerun evidence (out-main, out-main-c, out-main-bash32)
# and the rerun scripts into the tracked hand-back folder; every .sh keeps mode 0755.
set -euo pipefail
S="/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh"
HB="/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify/S3-CursorVerify-Bash"
mkdir -p "$HB/out-main" "$HB/scripts"
for f in cv-rerun-main.sh cv-copy-evidence-main.sh; do
    cp -p "$S/$f" "$HB/scripts/$f"
done
copy_phase() { # copy_phase SRCDIR DESTNAME
    local src="$1" dst="$HB/out-main/$2" f
    mkdir -p "$dst"
    for f in tree.txt tree-restored.txt bakdirs.txt rows.txt exit.txt checks.txt checks-run-after-P4-INVALID.txt \
             prompts.txt later-items.txt harness.summary cursor.summary commit.txt \
             edit-rule-survived.txt edit-skill-survived.txt rule-stems.diff skills.diff; do
        if [ -f "$src/$f" ]; then cp -p "$src/$f" "$dst/$f"; fi
    done
    case "$2" in P5|P5x) cp -p "$src/cursor.out" "$dst/cursor-pty-transcript.txt" ;; esac
}
for p in P1 P2 P3 P3b P4 P5 P5x; do copy_phase "$S/out-main/$p" "$p"; done
copy_phase "$S/out-main-bash32/P1" "P1-bash32"
copy_phase "$S/out-main-c/P1" "P1-checkrun"
cp -p "$S/out-main/diff-vs-9c2d025.txt" "$S/out-main/assertions.txt" "$HB/out-main/"
# exec bit on every .sh in the hand-back folder
find "$HB" -name '*.sh' -exec chmod 0755 {} +
find "$HB" -name '*.sh' ! -perm 0755 | grep -c . || true
