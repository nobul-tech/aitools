#!/usr/bin/env bash
# run-hook-tests.sh -- run the hook output-channel tests (HOOK2-AUDIT).
#
# Runs, in order: test-sh-file-fixup.sh, test-glossary-skill-guard.sh,
# test-sessionstart-harness-db.sh, test-hooks-smoke.sh. Each runs under
# AITOOLS_TEST_BASH (default bash), which is passed through, so
#   AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/run-hook-tests.sh
# runs both the tests and the hooks under macOS bash 3.2.
# test-delegation-duty-guard.sh (PR #122) has its own CI steps and is not run here.
# Exit 0 when every test file passes, 1 otherwise.
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run.
# Usage: bash tests/hooks/run-hook-tests.sh [--help]

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    sed -n '2,12p' "${BASH_SOURCE[0]}"
    exit 0
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_BIN="${AITOOLS_TEST_BASH:-bash}"
failed=""
for t in test-sh-file-fixup.sh test-glossary-skill-guard.sh test-sessionstart-harness-db.sh test-hooks-smoke.sh; do
    printf '\n### %s\n' "$t"
    if ! "$BASH_BIN" "$DIR/$t"; then
        failed="$failed $t"
    fi
done

if [ -n "$failed" ]; then
    printf '\nrun-hook-tests: FAILED:%s\n' "$failed"
    exit 1
fi
printf '\nrun-hook-tests: all hook test files passed\n'
