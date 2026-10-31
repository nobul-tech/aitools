#!/usr/bin/env bash
# watch-runs.sh RUN_ID... -- wait for each CI run; print its conclusion; exit 1 if any failed
set -uo pipefail
fail=0
for id in "$@"; do
    gh run watch "$id" --repo nobul-tech/aitools --exit-status > /dev/null 2>&1
    rc=$?
    concl=$(gh run view "$id" --repo nobul-tech/aitools --json conclusion,headBranch --jq '"\(.headBranch) \(.conclusion)"')
    printf 'run %s: %s (watch exit %s)\n' "$id" "$concl" "$rc"
    if [ "$rc" -ne 0 ]; then fail=1; fi
done
exit "$fail"
