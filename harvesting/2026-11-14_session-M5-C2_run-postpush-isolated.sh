#!/usr/bin/env bash
# Run check-post-push.ps1 from the worktree under an isolated HOME/USERPROFILE
# (plus APPDATA/LOCALAPPDATA, so tools run by step 21 cache there), logs in
# scratch, config.json pointing userRepoPath at a scratch clone of the
# dotprofile. Snapshots the real dotprofile deploy/, the copy's deploy/ and
# the real ~/.aitools/logs before and after, and diffs them.
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/m5-checks
S=$WT/.scratch/session-M5-C2
P=$S/pp
REAL_DOT=/c/Users/jdpal/repos/aitools-nobul-jose
REAL_LOGS=/c/Users/jdpal/.aitools/logs
mkdir -p "$P/home/.aitools" "$P/logs" "$P/appdata" "$P/localappdata"

if [ ! -d "$P/dot/.git" ]; then
    git clone -q "$REAL_DOT" "$P/dot"
    if [ -d "$REAL_DOT/deploy" ]; then cp -R "$REAL_DOT/deploy" "$P/dot/deploy"; fi
fi
w() { cygpath -w "$1"; }
printf '{\n  "repoPath": "%s",\n  "reposPath": "%s",\n  "userRepoPath": "%s"\n}\n' \
    "$(cygpath -m "$WT")" "$(cygpath -m "$P")" "$(cygpath -m "$P/dot")" > "$P/home/.aitools/config.json"
cat "$P/home/.aitools/config.json"

snap() {  # <dir> <out>: path, size, mtime of every file (and the dir itself)
    if [ -d "$1" ]; then
        { stat -c '%n %s %Y' "$1"; find "$1" -type f -exec stat -c '%n %s %Y' {} +; } | sort > "$2"
    else
        echo "missing: $1" > "$2"
    fi
}
snap "$REAL_DOT/deploy" "$P/before-real-deploy.txt"
snap "$P/dot/deploy" "$P/before-copy-deploy.txt"
snap "$REAL_LOGS" "$P/before-real-logs.txt"
git -C "$REAL_DOT" status --porcelain > "$P/before-real-dot-status.txt"

rc=0
env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
    HOME="$P/home" USERPROFILE="$(w "$P/home")" APPDATA="$(w "$P/appdata")" LOCALAPPDATA="$(w "$P/localappdata")" \
    AITOOLS_LOG_DIR="$(w "$P/logs")" \
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$(w "$WT/scripts/check-post-push.ps1")" > "$S/postpush.log" 2>&1 || rc=$?
echo "check-post-push.ps1 exit: $rc"

snap "$REAL_DOT/deploy" "$P/after-real-deploy.txt"
snap "$P/dot/deploy" "$P/after-copy-deploy.txt"
snap "$REAL_LOGS" "$P/after-real-logs.txt"
git -C "$REAL_DOT" status --porcelain > "$P/after-real-dot-status.txt"
for k in real-deploy copy-deploy real-logs real-dot-status; do
    if cmp -s "$P/before-$k.txt" "$P/after-$k.txt"; then
        echo "unchanged: $k ($(wc -l < "$P/before-$k.txt" | tr -d ' ') lines)"
    else
        echo "CHANGED: $k"; diff "$P/before-$k.txt" "$P/after-$k.txt" | head -20
    fi
done
perl -pe 's/\e\[[0-9;]*m//g' "$S/postpush.log" | grep -E "\[(FAIL|WARN|PASS|SKIP)\]|SUMMARY"
