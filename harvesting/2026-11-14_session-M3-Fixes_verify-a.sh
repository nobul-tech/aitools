#!/usr/bin/env bash
# Orchestrator verification of batch A (and B's test) in the worktree.
set -uo pipefail
W=C:/Users/jdpal/repos/aitools/.claude/worktrees/console-profile
S=$W/.scratch/session-M3-Fixes
cd "$W" || exit 1
export AITOOLS_LOG_DIR="$S/logs"
mkdir -p "$AITOOLS_LOG_DIR"

for f in scripts/setup-user-shell.sh scripts/aitools-install.sh tests/setup-user-shell/test-setup-user-shell.sh; do
    if bash -n "$f"; then echo "bash -n OK  $f"; else echo "bash -n FAIL $f"; fi
done
pwsh -NoProfile -File "$S/parse.ps1" scripts/setup-user-shell.ps1 scripts/aitools-install.ps1 scripts/aitools.ps1 tests/setup-user-shell/test-setup-user-shell.ps1 tests/aitools-entry/test-console-mode-guard.ps1

echo "== test-setup-user-shell.ps1"
pwsh -NoProfile -File tests/setup-user-shell/test-setup-user-shell.ps1 > "$S/t-shell-ps1.log" 2>&1
echo "exit $?"
grep -E "passed|FAIL" "$S/t-shell-ps1.log" | tail -n 5

echo "== test-setup-user-shell.sh (Git Bash: expect skip)"
bash tests/setup-user-shell/test-setup-user-shell.sh > "$S/t-shell-sh.log" 2>&1
echo "exit $?"
tail -n 3 "$S/t-shell-sh.log"

echo "== os-guards"
bash tests/os-guards/test-os-guards.sh > "$S/t-osguards.log" 2>&1
echo "exit $?"
tail -n 2 "$S/t-osguards.log"

echo "== console mode guard"
pwsh -NoProfile -File tests/aitools-entry/test-console-mode-guard.ps1 > "$S/t-cmg.log" 2>&1
echo "exit $?"
tail -n 1 "$S/t-cmg.log"

echo "== git modes"
git ls-files -s scripts/setup-user-shell.sh scripts/aitools-install.sh scripts/aitools-lib.sh
