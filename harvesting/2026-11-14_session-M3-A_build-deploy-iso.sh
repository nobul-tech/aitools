#!/usr/bin/env bash
# build-deploy-iso.sh -- run build-deploy.sh under an isolated HOME against a scratch
# clone of the dotprofile; then syntax-check the generated setup-user-shell pair.
set -euo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/console-profile
S=$WT/.scratch/session-M3-A/bd
rm -rf "$S"
mkdir -p "$S/home" "$S/logs"
git clone -q /c/Users/jdpal/repos/aitools-nobul-jose "$S/dotprofile"
rc=0
HOME="$S/home" USERPROFILE="$(cygpath -w "$S/home")" AITOOLS_USER_REPO_PATH="$S/dotprofile" AITOOLS_LOG_DIR="$S/logs" \
    bash "$WT/scripts/build-deploy.sh" > "$S/build.log" 2>&1 || rc=$?
echo "build-deploy exit: $rc"
tail -n 5 "$S/build.log"
ls -la "$S/dotprofile/deploy/setup-user-shell.sh" "$S/dotprofile/deploy/setup-user-shell.ps1"
if bash -n "$S/dotprofile/deploy/setup-user-shell.sh"; then echo "bash -n OK: deploy/setup-user-shell.sh"; else echo "bash -n FAIL"; fi
pwsh -NoProfile -File "$WT/.scratch/session-M3-A/parse-check.ps1" "$(cygpath -w "$S/dotprofile/deploy/setup-user-shell.ps1")"
echo "aliases in deploy tree:"
find "$S/dotprofile" -name 'aliases.*' -not -path '*/.git/*' | head -n 5
