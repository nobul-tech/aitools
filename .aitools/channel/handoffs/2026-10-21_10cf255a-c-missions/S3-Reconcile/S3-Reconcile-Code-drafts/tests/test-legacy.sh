#!/usr/bin/env bash
# Item 5: drafted setup-user-config.sh migrates aiToolingRepoPath (isolated HOME)
set -euo pipefail
S=/Users/new-jose/repos/aitools/.scratch/session-rccode
C="$S/repo-claim"
for case in only both; do
  H="$S/legacy-$case"
  rm -rf "$H"
  mkdir -p "$H/.aitools" "$H/repos"
  if [ "$case" = "only" ]; then
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "aiToolingRepoPath": "/Users/x/repos/ai-tooling",\n  "keep": "me"\n}\n' "$H/repos" > "$H/.aitools/config.json"
  else
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "/Users/x/repos/aitools-real",\n  "aiToolingRepoPath": "/Users/x/repos/ai-tooling"\n}\n' "$H/repos" > "$H/.aitools/config.json"
  fi
  rc=0
  env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_SUMMARY_FILE HOME="$H" AITOOLS_LOG_DIR="$H/logs" \
      bash "$C/scripts/setup-user-config.sh" > "$H/out.txt" 2>&1 || rc=$?
  echo "== case $case: exit $rc"
  grep -E 'legacy|aiToolingRepoPath|repoPath' "$H/out.txt" || true
  echo "-- config.json:"
  perl -ne 'print if /repoPath|aiToolingRepoPath|keep/' "$H/.aitools/config.json"
  echo "-- backups: $(ls "$H/.aitools" | grep -c 'config.json.bak' || true)"
done
