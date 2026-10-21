#!/usr/bin/env bash
# test-review-fixes.sh -- regression checks for the S5-Profile-A findings fixed in drafts
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
JS="$M/S5-Profile-drafts/scripts/aitools-profile.js"
T="$M/tests/run-fixes"
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/home/repos/aitools-nobul-jose" "$T/logs" "$T/other"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/home/repos/aitools-nobul-jose/profile.json"
C="$T/home/.aitools/config.json"
echo "== H1: lib names / '@ lines in resolver (expect none)"
grep -nE "^'@|aitools-lib\.ps1|source.*aitools-lib\.sh" "$JS" || echo "none"
echo "== H1: simulate inline_lib_ps1 on the resolver, then node --check"
perl -e 'open my $l,"<",$ARGV[0] or die;my $c=do{local $/;<$l>};while(<STDIN>){if(/aitools-lib\.ps1/){print $c}else{print}}' /Users/new-jose/repos/aitools/scripts/aitools-lib.ps1 < "$JS" > "$T/inlined.js"
node --check "$T/inlined.js"
echo "inlined node --check rc=0; lines: $(wc -l < "$T/inlined.js") vs $(wc -l < "$JS")"
printf '{ "version": 2, "reposPath": "%s/home/repos", ' "$T" > "$C"
rc=0; out=$(HOME="$T/home" node "$JS" user-repo-path --config "$C" --format tagged) || rc=$?
echo "== H3/H4 corrupt config, user-repo-path rc=$rc"; printf '%s\n' "$out"
printf '{"version":3,"reposPath":"%s/home/repos","repoPath":"/x","userRepoPath":"%s/home/repos/aitools-nobul-jose"}\n' "$T" "$T" > "$C"
rc=0; out=$(HOME="$T/home" AITOOLS_USER_REPO_PATH="$T/other" node "$JS" derive-config --config "$C" --user-repo-path "$T/home/repos/aitools-nobul-jose") || rc=$?
echo "== M1 explicit arg beats env (rc=$rc)"; printf '%s\n' "$out" | perl -ne 'print "$1\n" if /"userRepoVia":"(\w+)"/'
rc=0; out=$(HOME="$T/home" AITOOLS_MACHINE_ALIAS=laptop node "$JS" derive-config --config "$C") || rc=$?
echo "== M1 env alias not persisted (rc=$rc)"; printf '%s\n' "$out" | perl -ne 'print((/"machineAlias"/ ? "PERSISTED (bad)" : "not persisted (ok)")."\n")'
rc=0; out=$(HOME="$T/home" AITOOLS_PROFILE_FILE="$T/nope.json" node "$JS" resolve --config "$C" --format tagged) || rc=$?
echo "== M4 missing AITOOLS_PROFILE_FILE rc=$rc (expect 2)"; printf '%s\n' "$out" | perl -ne 'print if /^error/'
node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync(process.argv[1]));p.profiles.broken=null;fs.writeFileSync(process.argv[2],JSON.stringify(p))' "$T/home/repos/aitools-nobul-jose/profile.json" "$T/nullprof.json"
rc=0; out=$(HOME="$T/home" node "$JS" resolve --config "$C" --profile "$T/nullprof.json" --format tagged) || rc=$?
echo "== M9 null profile entry rc=$rc (expect 0, warning)"; printf '%s\n' "$out" | perl -ne 'print if /^(alias|via|warn)/'
echo "== H2 crashed resolver is an error, not shared-only"
printf 'syntax error here(\n' > "$T/broken.js"
cat > "$T/h2.sh" <<EOF
set -euo pipefail
export HOME="$T/home" AITOOLS_LOG_DIR="$T/logs" AITOOLS_PROFILE_JS="$T/broken.js"
source /Users/new-jose/repos/aitools/scripts/aitools-lib.sh
source "$M/S5-Profile-drafts/scripts/aitools-lib.sh.profile-block.sh"
logging_init "s5-fixes"
rc=0; resolve_user_repo_path || rc=\$?
echo "resolve_user_repo_path rc=\$rc ERRORS=\$ERRORS"
rc=0; resolve_machine_profile || rc=\$?
echo "resolve_machine_profile rc=\$rc ERRORS=\$ERRORS"
EOF
bash "$T/h2.sh" 2>&1 | perl -ne 'print if /rc=|\[error\]/'
echo "== machine-id (keyed hash)"; node "$JS" machine-id
