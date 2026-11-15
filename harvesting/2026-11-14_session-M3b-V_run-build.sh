#!/usr/bin/env bash
# run-build.sh -- M3b-Finish-V: isolated build-deploy from the worktree into a
# scratch clone of the dotprofile, then bash -n / pwsh parse every generated
# script and grep the inlined aitools-lib.ps1 markers.
set -uo pipefail

WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/console-input"
S="$WT/.scratch/session-M3b-V"
mkdir -p "$S/home-build" "$S/logs-build"

export HOME="$S/home-build"
export USERPROFILE="$(cygpath -w "$S/home-build")"
export AITOOLS_LOG_DIR="$S/logs-build"
export AITOOLS_USER_REPO_PATH="$S/dotprofile"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] build-deploy start (HOME=$HOME, AITOOLS_USER_REPO_PATH=$AITOOLS_USER_REPO_PATH)"
bash "$WT/scripts/build-deploy.sh" < /dev/null
rc=$?
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] build-deploy exit=$rc"

D="$S/dotprofile/deploy"
if [ ! -d "$D" ]; then
    echo "NO deploy/ directory generated at $D"
    exit 1
fi

echo "== generated files =="
ls -la "$D"

echo "== bash -n =="
nsh=0; badsh=0
for f in "$D"/*.sh; do
    [ -f "$f" ] || continue
    nsh=$((nsh + 1))
    if ! bash -n "$f" 2> "$S/bash-n-err.tmp"; then
        echo "FAIL bash -n: $(basename "$f")"
        cat "$S/bash-n-err.tmp"
        badsh=$((badsh + 1))
    fi
done
echo "bash -n: $nsh files, $badsh failed"

echo "== pwsh parser =="
pwsh -NoProfile -File "$S/parse-ps1.ps1" -Dir "$(cygpath -w "$D")"
prc=$?
echo "pwsh parse exit=$prc"

echo "== aitools-lib.ps1 inline markers (per generated .ps1) =="
for f in "$D"/*.ps1; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    lib=$(grep -c 'function Initialize-Logging' "$f")
    aci=$(grep -c 'AitConsoleInput' "$f")
    wal=$(grep -c 'Write-AiLog' "$f")
    sj=$(grep -c 'Start-Job' "$f")
    spin=$(grep -c 'function Start-AiSpinner' "$f")
    echo "$b inlinesLib=$lib AitConsoleInput=$aci Write-AiLog=$wal Start-Job=$sj Start-AiSpinner=$spin"
done
echo "== Start-Job lines (if any) =="
grep -n 'Start-Job' "$D"/*.ps1
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] done"
exit $rc
