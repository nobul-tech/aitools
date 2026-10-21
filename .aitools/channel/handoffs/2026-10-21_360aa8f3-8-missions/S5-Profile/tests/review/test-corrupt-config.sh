#!/usr/bin/env bash
# test-corrupt-config.sh -- corrupt config.json through the resolver CLI forms and the bash wrapper
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
JS="$M/S5-Profile-drafts/scripts/aitools-profile.js"
T="$M/tests/review/run-corrupt"
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/home/repos/aitools-nobul-jose" "$T/logs"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/home/repos/aitools-nobul-jose/profile.json"
C="$T/home/.aitools/config.json"
printf '{ "version": 2, "reposPath": "%s/home/repos", "userRepoPath": "%s/home/repos/aitools-nobul-jose", ' "$T" "$T" > "$C"
for form in "--format mixed" "--format tagged" "--json"; do
    rc=0
    out=$(HOME="$T/home" node "$JS" user-repo-path --config "$C" $form 2>"$T/err.txt") || rc=$?
    printf '== user-repo-path %s: exit=%s stdout=[%s] stderr=[%s]\n' "$form" "$rc" "$out" "$(perl -ne 'print' "$T/err.txt")"
done
# bash wrapper: does the error reach deploy.log and ERRORS?
export HOME="$T/home" AITOOLS_LOG_DIR="$T/logs" AITOOLS_PROFILE_JS="$JS"
source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
source "$M/S5-Profile-drafts/scripts/aitools-lib.sh.profile-block.sh"
logging_init "s5a-corrupt"
rc=0
resolve_user_repo_path 2>"$T/wrapper-err.txt" || rc=$?
printf '== wrapper rc=%s ERRORS=%s WARNINGS=%s\n' "$rc" "$ERRORS" "$WARNINGS"
printf -- '-- deploy.log lines mentioning dotprofile/invalid --\n'
perl -ne 'print if /dotprofile|invalid JSON/' "$T/logs/deploy.log"
