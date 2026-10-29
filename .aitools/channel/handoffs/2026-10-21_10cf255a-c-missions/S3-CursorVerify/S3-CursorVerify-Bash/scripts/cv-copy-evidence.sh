#!/usr/bin/env bash
# cv-copy-evidence.sh -- copy the runners, the generator and the small per-phase outputs
# into the tracked hand-back folder (logs and snapshots stay in scratch).
set -euo pipefail
S="/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh"
HB="/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-CursorVerify/S3-CursorVerify-Bash"
mkdir -p "$HB/scripts" "$HB/out"
for f in cvgen.pl cv-phase.sh cv-check-p1.sh cv-pty.py cv-p5.sh cv-copy-evidence.sh; do
    cp -p "$S/$f" "$HB/scripts/$f"
done
copy_phase() { # copy_phase SRCDIR DESTNAME
    local src="$1" dst="$HB/out/$2" f
    mkdir -p "$dst"
    for f in tree.txt tree-restored.txt bakdirs.txt rows.txt exit.txt checks.txt prompts.txt later-items.txt \
             harness.summary cursor.summary commit.txt edit-rule-survived.txt edit-skill-survived.txt \
             rule-stems.diff skills.diff; do
        if [ -f "$src/$f" ]; then cp -p "$src/$f" "$dst/$f"; fi
    done
    # P5/P5x: the pty transcript is the prompt evidence
    case "$2" in P5|P5x) cp -p "$src/cursor.out" "$dst/cursor-pty-transcript.txt" ;; esac
}
for p in P1 P2 P3 P3b P4 P5 P5x; do copy_phase "$S/out/$p" "$p"; done
copy_phase "$S/out-bash32/P1" "P1-bash32"
ls -R "$HB" | grep -c .
