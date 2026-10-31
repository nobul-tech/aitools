#!/usr/bin/env bash
# ps-suites.sh CLONE... -- run the pwsh suites in each clone with HOME set to a temp dir
set -uo pipefail
for c in "$@"; do
    H=$(mktemp -d /tmp/rcfixc-pshome.XXXXXX)
    for t in tests/managed-files/test-managed-files.ps1 tests/logging/test-logging.ps1; do
        rc=0
        (cd "$c" && HOME="$H" pwsh -NoProfile -File "$t" > "$H/$(basename "$t").out" 2>&1 < /dev/null) || rc=$?
        echo "$c $t rc=$rc :: $(grep -E -i 'passed|failed' "$H/$(basename "$t").out" | tail -1)"
    done
done
