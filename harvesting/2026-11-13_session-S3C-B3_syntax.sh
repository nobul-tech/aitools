#!/usr/bin/env bash
set -uo pipefail
rc=0
for f in scripts/aitools-lib.sh scripts/deploy-harness.sh scripts/build-deploy.sh tests/deploy-harness/test-deploy-harness.sh; do
    if bash -n "/Users/new-jose/repos/aitools/$f"; then
        printf 'OK bash -n %s\n' "$f"
    else
        printf 'FAIL bash -n %s\n' "$f"; rc=1
    fi
done
exit "$rc"
