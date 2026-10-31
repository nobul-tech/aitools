#!/usr/bin/env bash
# sync-after-commit.sh -- verify local copies match commit 81d4aae, drop them, ff-pull (scratch).
set -euo pipefail
R=/Users/new-jose/repos/aitools
C=81d4aaeeeb5e50cd98cd7873578299bdfca043b1
D=".aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmWinToolDR"
N="$D/research_notes/Intunewin packaging without Windows"
files=(
  "$D/reports/Intunewin packaging without Windows.md"
  "$N/community_packers.md"
  "$N/emulation_and_ci_runners.md"
  "$N/format_and_native_build.md"
  "$N/mdm_ecosystem_practice.md"
  "$N/official_microsoft_tooling.md"
)
for f in "${files[@]}" plans/build-package/mdm-windows-tool-findings.md; do
  want=$(git -C "$R" rev-parse "$C:$f")
  have=$(git -C "$R" hash-object "$R/$f")
  if [ "$want" != "$have" ]; then
    printf '%s [sync] [error] mismatch, aborting: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$f"
    exit 1
  fi
done
for f in "${files[@]}"; do rm "$R/$f"; done
git -C "$R" checkout -- plans/build-package/mdm-windows-tool-findings.md
git -C "$R" pull --ff-only
printf '%s [sync] [ok] pulled; HEAD=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(git -C "$R" rev-parse HEAD)"
