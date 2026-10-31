#!/usr/bin/env bash
# wait-notes.sh -- wait until all three delegate notes files exist (scratch helper)
set -euo pipefail
D=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmWinTool
for n in Eval Research Probe; do
  until test -f "$D/S3-MdmWinTool-$n-notes.md"; do
    sleep 30
  done
  echo "present: $n"
done
