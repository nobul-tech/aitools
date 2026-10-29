#!/usr/bin/env bash
# make-main.sh -- copy the S3-CursorVerify-Pwsh runners into main/ retargeted at
# ROOT=.../session-cv-ps/fx-main and outputs .../session-cv-ps/out-main (rerun at 207f1a6)
set -euo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
mkdir -p "$S/main"
for f in run-phase.sh check-p1.sh check-sources.sh p3-edit.sh p4-prep.sh p5.sh p6x-retire-br.sh p7x-br-update.sh p8x-upper-retire.sh; do
    perl -pe 's{\$S/fx\b}{\$S/fx-main}g; s{\$S/out\b}{\$S/out-main}g; s{session-cv-ps/fx/}{session-cv-ps/fx-main/}g; s{session-cv-ps/fx"}{session-cv-ps/fx-main"}g' "$S/$f" > "$S/main/$f"
    chmod +x "$S/main/$f"
done
grep -n -E 'fx-main|out-main|/fx\b|/out\b' "$S/main/"*.sh | grep -v -E 'fx-main|out-main' || echo "no unretargeted fx/out paths"
mkdir -p "$S/out-main/P0"
