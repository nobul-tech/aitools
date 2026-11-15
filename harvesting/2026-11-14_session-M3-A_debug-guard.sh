#!/usr/bin/env bash
set -euo pipefail
S=/c/Users/jdpal/repos/aitools/.claude/worktrees/console-profile/.scratch/session-M3-A
D=$S/dbg-guard
rm -rf "$D"
mkdir -p "$D/home"
printf 'if true; then\n%s\nfi\n%s\n' "# >>> aitools managed >>>" "# <<< aitools managed <<<" > "$D/.bash_profile"
rc=0
HOME="$D/home" AITOOLS_PROFILE_DIR="$D" AITOOLS_ALIASES_PATH="$D/none" AITOOLS_LOG_DIR="$D/logs" AITOOLS_SUMMARY_FILE="$D/summary.txt" \
    bash "$S/mirror/scripts/setup-user-shell.sh" > "$D/run.log" 2>&1 || rc=$?
echo "rc=$rc"
cat "$D/summary.txt"
cat "$D/run.log"
echo ----
cat "$D/.bash_profile"
bash -n "$D/.bash_profile" || echo "bash -n fails"
