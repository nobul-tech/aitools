#!/usr/bin/env bash
# commit.sh -- commit MDM-WINTOOL deliverable + mission folder onto origin/main (scratch)
set -euo pipefail
R=/Users/new-jose/repos/aitools
M=.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MdmWinTool
bash "$R/.scratch/session-10cf255a-c/commit-onto-origin.sh" "$R/.scratch/session-mdmwin/commit-msg.txt" \
  "plans/build-package/mdm-windows-tool-findings.md=$R/plans/build-package/mdm-windows-tool-findings.md" \
  "$M/S3-MdmWinTool-Eval-notes.md=$R/$M/S3-MdmWinTool-Eval-notes.md" \
  "$M/S3-MdmWinTool-Research-notes.md=$R/$M/S3-MdmWinTool-Research-notes.md" \
  "$M/S3-MdmWinTool-Probe-notes.md=$R/$M/S3-MdmWinTool-Probe-notes.md" \
  "$M/S3-MdmWinTool-Critic-verdict.md=$R/$M/S3-MdmWinTool-Critic-verdict.md"
