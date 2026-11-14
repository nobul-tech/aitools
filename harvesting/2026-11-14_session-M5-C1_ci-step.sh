#!/usr/bin/env bash
# ci-step.sh -- the "Every test suite is in CI" run: line, verbatim, from the worktree root
set -uo pipefail
cd /c/Users/jdpal/repos/aitools/.claude/worktrees/m5-checks
git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1' | perl scripts/check-ci-suites.pl .github/workflows/check.yml
echo "exit: $?"
git ls-files -s scripts/check-ci-suites.pl tests/ci-suites/test-check-ci-suites.sh
