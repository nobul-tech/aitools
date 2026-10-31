#!/usr/bin/env bash
# Reproduce pre-push step 7's rebuild-and-compare in an isolated HOME (same
# method as check-pre-push.sh step 7): build from the main checkout (8e18ad4,
# scripts identical to 8e490d7) into a temp copy of the dotprofile's committed
# tree. The real dotprofile and the real HOME are never written.
set -euo pipefail
R=/Users/new-jose/repos/aitools
DP=/Users/new-jose/repos/aitools-nobul-jose
T=/Users/new-jose/repos/aitools/.scratch/session-rccode/s7
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/dot" "$T/committed"
git -C "$DP" archive -o "$T/dot.tar" HEAD
tar -xf "$T/dot.tar" -C "$T/dot"
tar -xf "$T/dot.tar" -C "$T/committed"
rm -rf "$T/dot/deploy"
printf '{\n  "version": 3,\n  "reposPath": "/Users/new-jose/repos",\n  "repoPath": "%s",\n  "userRepoPath": "%s"\n}\n' "$R" "$T/dot" > "$T/home/.aitools/config.json"
rc=0
env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
    HOME="$T/home" AITOOLS_USER_REPO_PATH="$T/dot" bash "$R/scripts/build-deploy.sh" > "$T/build.txt" 2>&1 || rc=$?
echo "build rc=$rc"
if [ -d "$T/dot/deploy" ]; then
  drc=0
  diff -rq "$T/committed/deploy" "$T/dot/deploy" > "$T/diff.txt" 2>&1 || drc=$?
  echo "diff rc=$drc lines=$(wc -l < "$T/diff.txt")"
  echo "only in fresh build:"
  grep "Only in $T/dot/deploy" "$T/diff.txt" || true
  echo "only in committed:"
  grep "Only in $T/committed/deploy" "$T/diff.txt" || true
  echo "differ count: $(grep -c ' differ$' "$T/diff.txt" || true)"
  ls "$T/dot/deploy" | wc -l
  ls "$T/committed/deploy" | wc -l
else
  echo "no deploy/ built"
  tail -20 "$T/build.txt"
fi
