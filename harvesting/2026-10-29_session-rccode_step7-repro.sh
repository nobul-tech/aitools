#!/usr/bin/env bash
# Second isolated build: is build-deploy output reproducible (else step 7 can never pass)?
set -euo pipefail
R=/Users/new-jose/repos/aitools
DP=/Users/new-jose/repos/aitools-nobul-jose
T=/Users/new-jose/repos/aitools/.scratch/session-rccode/s7b
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/dot"
git -C "$DP" archive -o "$T/dot.tar" HEAD
tar -xf "$T/dot.tar" -C "$T/dot"
rm -rf "$T/dot/deploy"
printf '{\n  "version": 3,\n  "reposPath": "/Users/new-jose/repos",\n  "repoPath": "%s",\n  "userRepoPath": "%s"\n}\n' "$R" "$T/dot" > "$T/home/.aitools/config.json"
env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
    HOME="$T/home" AITOOLS_USER_REPO_PATH="$T/dot" bash "$R/scripts/build-deploy.sh" > "$T/build.txt" 2>&1
drc=0
diff -rq "/Users/new-jose/repos/aitools/.scratch/session-rccode/s7/dot/deploy" "$T/dot/deploy" || drc=$?
echo "repro diff rc=$drc"
