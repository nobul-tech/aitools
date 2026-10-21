#!/usr/bin/env bash
# test-lib-wrappers.sh -- exercise the drafted bash lib wrappers against an isolated
# HOME and an isolated log dir. Sources the real aitools-lib.sh read-only.
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
T="$M/tests/run-lib"
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/home/repos/aitools-nobul-jose" "$T/logs"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/home/repos/aitools-nobul-jose/profile.json"
export HOME="$T/home"
export AITOOLS_LOG_DIR="$T/logs"
export AITOOLS_PROFILE_JS="$M/S5-Profile-drafts/scripts/aitools-profile.js"
source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
source "$M/S5-Profile-drafts/scripts/aitools-lib.sh.profile-block.sh"
logging_init "s5-test"

printf '{"version":2,"reposPath":"%s/home/repos","repoPath":"/x","githubUser":"nobul-jose"}\n' "$T" > "$HOME/.aitools/config.json"
rc=0; resolve_user_repo_path || rc=$?
echo "W1 rc=$rc path=$USER_REPO_PATH via=$USER_REPO_VIA"
rc=0; resolve_machine_profile || rc=$?
echo "W2 rc=$rc alias=$MACHINE_ALIAS via=$MACHINE_VIA company=$PROFILE_COMPANY name=$PROFILE_NAME git=$IDENTITY_GIT_EMAIL"
node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync(process.argv[1]));p.profiles["new-mac"].machine.hostname="zzz";fs.writeFileSync(process.argv[1],JSON.stringify(p))' "$HOME/repos/aitools-nobul-jose/profile.json"
rc=0; resolve_machine_profile || rc=$?
echo "W3 rc=$rc alias='$MACHINE_ALIAS' company='$PROFILE_COMPANY' ERRORS=$ERRORS WARNINGS=$WARNINGS"
rm -rf "$HOME/repos/aitools-nobul-jose"
rc=0; resolve_machine_profile || rc=$?
echo "W4 rc=$rc (no dotprofile)"
echo "--- deploy.log ---"
cat "$T/logs/deploy.log"
