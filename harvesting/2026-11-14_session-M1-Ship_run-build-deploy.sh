#!/usr/bin/env bash
# run-build-deploy.sh -- build-deploy.sh under an isolated HOME into a dotprofile
# clone in scratch; then bash -n / pwsh parse every generated script and check the
# two deploy-harness anchors made it through.
set -uo pipefail
S="C:/Users/jdpal/repos/aitools/.claude/worktrees/json-review/.scratch/session-M1-Ship"
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/json-review"
env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
    HOME="$S/home" USERPROFILE="$S/home" AITOOLS_LOG_DIR="$S/home/logs" AITOOLS_USER_REPO_PATH="$S/dot" \
    bash "$WT/scripts/build-deploy.sh" > "$S/build-deploy.log" 2>&1
rc=$?
echo "build-deploy rc=$rc"
grep -cE '\[error\]' "$S/build-deploy.log" | sed 's/^/error lines: /'
grep -E '\[(warn|error)\]' "$S/build-deploy.log"
n=0; bad=0
for f in "$S"/dot/deploy/*.sh; do
    n=$((n + 1)); bash -n "$f" || { echo "bash -n FAIL $f"; bad=$((bad + 1)); }
done
echo "bash -n: $n files, $bad failed"
pwsh -NoProfile -Command "\$bad = 0; \$n = 0; Get-ChildItem '$S/dot/deploy/*.ps1' | ForEach-Object { \$n++; \$e = \$null; \$null = [System.Management.Automation.Language.Parser]::ParseFile(\$_.FullName, [ref]\$null, [ref]\$e); if (\$e) { \$bad++; 'pwsh parse FAIL ' + \$_.Name } }; 'pwsh parse: ' + \$n + ' files, ' + \$bad + ' failed'"
grep -c 'NoReview:\$readOnlyCopy' "$S/dot/deploy/deploy-harness.ps1" | sed 's/^/ps1 NoReview lines: /'
grep -c 'MANAGED_NO_REVIEW="\$no_review"' "$S/dot/deploy/deploy-harness.sh" | sed 's/^/sh MANAGED_NO_REVIEW lines: /'
git -C "$S/dot" status --short | head -n 5
exit $rc
