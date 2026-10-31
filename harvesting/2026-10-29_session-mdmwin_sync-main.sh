#!/usr/bin/env bash
# sync-main.sh -- move my untracked copies (if identical to the pushed commit) aside, then ff-pull (scratch)
set -euo pipefail
R=/Users/new-jose/repos/aitools
C=c41237739588743ecc145a40da4114d3aa31f7c3
B=$R/.scratch/session-mdmwin/pre-pull-backup
M=.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmWinTool
mkdir -p "$B"
for p in plans/build-package/mdm-windows-tool-findings.md \
  "$M/S3-MdmWinTool-Eval-notes.md" "$M/S3-MdmWinTool-Research-notes.md" \
  "$M/S3-MdmWinTool-Probe-notes.md" "$M/S3-MdmWinTool-Critic-verdict.md"; do
  if git -C "$R" show "$C:$p" | cmp -s - "$R/$p"; then
    mv "$R/$p" "$B/$(basename "$p")"
    echo "moved identical: $p"
  else
    echo "DIFFERS, left in place: $p"
    exit 1
  fi
done
git -C "$R" pull --ff-only
git -C "$R" log -1 --format=%H
