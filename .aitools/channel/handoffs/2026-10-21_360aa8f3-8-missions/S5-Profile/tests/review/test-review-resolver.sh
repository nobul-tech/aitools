#!/usr/bin/env bash
# test-review-resolver.sh -- adversarial checks of the drafted resolver + writer.
# Isolated HOME under tests/review/; never touches ~/.aitools or the real dotprofile.
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
JS="$M/S5-Profile-drafts/scripts/aitools-profile.js"
R="/Users/new-jose/repos/aitools/scripts"
T="$M/tests/review/run-resolver"
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/home/repos/aitools-nobul-jose" "$T/other-dot" "$T/scripts" "$T/logs"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/home/repos/aitools-nobul-jose/profile.json"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/other-dot/profile.json"
C="$T/home/.aitools/config.json"
printf '{"version":2,"reposPath":"%s/home/repos","repoPath":"/x","userRepoPath":"%s/home/repos/aitools-nobul-jose","machineAlias":"new-mac"}\n' "$T" "$T" > "$C"
run() { local name="$1"; shift; local rc=0; local out; out=$(HOME="$T/home" "$@" 2>&1) || rc=$?; printf '== %s (exit %s)\n%s\n' "$name" "$rc" "$out"; }

# R1: a node-level failure (syntax error in the resolver file) exits 1 = "not found"
printf 'const x = ;\n' > "$T/broken.js"
run "R1 broken resolver file -> node exit code" node "$T/broken.js" user-repo-path --config "$C" --format tagged

# R2: env override beats the explicit --user-repo-path argument
run "R2 env AITOOLS_USER_REPO_PATH vs --user-repo-path" env AITOOLS_USER_REPO_PATH="$T/other-dot" node "$JS" derive-config --config "$C" --user-repo-path "$T/home/repos/aitools-nobul-jose"

# R3: AITOOLS_PROFILE_FILE set to a missing file (stale env after an in-process deploy run)
run "R3 stale AITOOLS_PROFILE_FILE" env AITOOLS_PROFILE_FILE="$T/gone/profile.json" node "$JS" resolve --config "$C" --format tagged

# R4: writer persists an env-override dotprofile into config.json
cp "$R/aitools-lib.sh" "$T/scripts/aitools-lib.sh"
cat "$M/S5-Profile-drafts/scripts/aitools-lib.sh.profile-block.sh" >> "$T/scripts/aitools-lib.sh"
perl -ne 'print if /^validate_json_config\(\) \{/ .. /^}/' "$R/aitools-install.sh" >> "$T/scripts/aitools-lib.sh"
cp "$JS" "$M/S5-Profile-drafts/scripts/setup-user-config.sh" "$T/scripts/"
rc=0
HOME="$T/home" AITOOLS_LOG_DIR="$T/logs" AITOOLS_USER_REPO_PATH="$T/other-dot" bash "$T/scripts/setup-user-config.sh" > "$T/r4.txt" 2>&1 || rc=$?
printf '== R4 writer with exported AITOOLS_USER_REPO_PATH (exit %s)\n' "$rc"
perl -ne 'print if /"userRepoPath"/' "$C"

# R5: invalid profile entry (null) -> exit code
node -e 'const fs=require("fs");const f=process.argv[1];const p=JSON.parse(fs.readFileSync(f));p.profiles.broken=null;fs.writeFileSync(f,JSON.stringify(p))' "$T/other-dot/profile.json"
run "R5 null profile entry" node "$JS" resolve --config "$C" --profile "$T/other-dot/profile.json" --format tagged

# R6: profile-check style require + resolveMachine on null entry throws
run "R6 require + resolveMachine(null entry)" node -e 'const r=require(process.argv[1]);const p=JSON.parse(require("fs").readFileSync(process.argv[2]));console.log(JSON.stringify(r.resolveMachine(p,{configAlias:""})).slice(0,120))' "$JS" "$T/other-dot/profile.json"
