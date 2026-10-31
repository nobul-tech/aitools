#!/usr/bin/env bash
# run check-pre-commit (no --fix: never runs build-deploy) from the export tree
set -uo pipefail
cd /Users/new-jose/repos/aitools/.scratch/session-rcbar/tree
bash scripts/check-pre-commit.sh > /Users/new-jose/repos/aitools/.scratch/session-rcbar/precommit.txt 2>&1
printf 'exit=%s\n' "$?"
