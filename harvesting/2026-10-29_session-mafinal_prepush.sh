#!/usr/bin/env bash
# Run check-pre-push from the main checkout and capture the log (S3-MA-Final).
set -euo pipefail
cd /Users/new-jose/repos/aitools
rc=0
bash scripts/check-pre-push.sh > /Users/new-jose/repos/aitools/.scratch/session-mafinal/prepush.log 2>&1 || rc=$?
printf 'check-pre-push exit: %s\n' "$rc"
grep -E '^\s*\[(PASS|FAIL|WARN|SKIP)\]|Step 7|step 7' /Users/new-jose/repos/aitools/.scratch/session-mafinal/prepush.log | head -40 || printf 'no step lines matched\n'
