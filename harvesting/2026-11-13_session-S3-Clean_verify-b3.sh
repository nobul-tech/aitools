#!/usr/bin/env bash
# Syntax-check B3's files and run the deploy-harness suite.
set -euo pipefail
cd /Users/new-jose/repos/aitools
s=/Users/new-jose/repos/aitools/.scratch/session-S3-Clean
for f in scripts/aitools-lib.sh scripts/deploy-harness.sh scripts/build-deploy.sh tests/deploy-harness/test-deploy-harness.sh scripts/check-post-push.sh; do
    bash -n "$f"
    printf 'bash -n OK %s\n' "$f"
done
pwsh -NoProfile -File "$s/parse.ps1"
rc=0
bash tests/deploy-harness/test-deploy-harness.sh > "$s/deploy-harness.log" 2>&1 || rc=$?
printf 'test-deploy-harness exit %s\n' "$rc"
grep -E 'passed|FAIL' "$s/deploy-harness.log" | grep -v '^ *PASS' | tail -n 5
