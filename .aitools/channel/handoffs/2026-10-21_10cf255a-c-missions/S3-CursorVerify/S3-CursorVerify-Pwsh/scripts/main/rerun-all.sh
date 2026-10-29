#!/usr/bin/env bash
# rerun-all.sh -- S3-CursorVerify-Pwsh rerun at REF 207f1a6 on a fresh fixture fx-main:
# build, P0 snapshot, P1, P2, P3 (dry), P3b, P4, P5 (s, x), PX-br, PX-br-restore,
# PX-br-update, PX-upper. Same drivers and steps as the 9c2d025 run.
set -uo pipefail
S=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps
M="$S/main"; REF=207f1a6c7db92227e9c3ae3c5d44e8e6f6b19126
step() { printf '\n===== %s\n' "$*"; "$@"; printf -- '----- rc=%s\n' "$?"; }
step bash /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cverify/build-fixture.sh build "$S/fx-main" "$REF"
step git -C "$S/fx-main/aitools" log --oneline -2
step perl "$S/gen-tree.pl" "$S/fx-main/home" "$S/out-main/P0"
step bash "$M/run-phase.sh" P1
step bash "$M/check-sources.sh"
bash "$M/check-p1.sh" > "$S/out-main/P1/check-p1.txt" 2>&1
step bash "$M/run-phase.sh" P2
step bash "$M/p3-edit.sh"
step bash "$M/run-phase.sh" P3 --dry-run
step bash "$M/run-phase.sh" P3b
step bash "$M/p4-prep.sh"
step bash "$M/run-phase.sh" P4
step bash "$M/p5.sh" prep
step bash "$M/p5.sh" run-s
step bash "$M/p5.sh" prep-x
step bash "$M/p5.sh" run-x
step ls "$S/fx-main/home/.cursor/rules/web-sources.mdc" "$S/fx-main/home/.cursor/skills/tool-ops/SKILL.md"
step shasum -a 256 "$S/fx-main/home/.cursor/rules/fx-shared.mdc" "$S/fx-main/home/.cursor/skills/fx-skill-b/SKILL.md"
step bash "$M/p6x-retire-br.sh"
step bash "$M/run-phase.sh" PX-br
step bash "$M/p7x-br-update.sh" restore
step bash "$M/run-phase.sh" PX-br-restore
step bash "$M/p7x-br-update.sh" edit
step bash "$M/run-phase.sh" PX-br-update
step bash "$M/p8x-upper-retire.sh"
step bash "$M/run-phase.sh" PX-upper
