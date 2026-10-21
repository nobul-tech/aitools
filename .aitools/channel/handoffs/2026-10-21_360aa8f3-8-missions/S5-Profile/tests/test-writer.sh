#!/usr/bin/env bash
# test-writer.sh -- run the drafted setup-user-config.sh against an isolated HOME.
# Builds a throwaway scripts/ dir: real aitools-lib.sh + drafted profile block +
# validate_json_config (copied from aitools-install.sh, as the plan moves it to the lib).
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
R="/Users/new-jose/repos/aitools/scripts"
T="$M/tests/run-writer"
rm -rf "$T"
mkdir -p "$T/scripts" "$T/home/repos/aitools-nobul-jose" "$T/logs"
cp "$R/aitools-lib.sh" "$T/scripts/aitools-lib.sh"
cat "$M/S5-Profile-drafts/scripts/aitools-lib.sh.profile-block.sh" >> "$T/scripts/aitools-lib.sh"
perl -ne 'print if /^validate_json_config\(\) \{/ .. /^}/' "$R/aitools-install.sh" >> "$T/scripts/aitools-lib.sh"
cp "$M/S5-Profile-drafts/scripts/aitools-profile.js" "$M/S5-Profile-drafts/scripts/setup-user-config.sh" "$T/scripts/"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/home/repos/aitools-nobul-jose/profile.json"
export HOME="$T/home" AITOOLS_LOG_DIR="$T/logs"
W="$T/scripts/setup-user-config.sh"
run() { local name="$1"; shift; local rc=0; "$@" > "$T/out.txt" 2>&1 || rc=$?; printf '== %s (exit %s)\n' "$name" "$rc"; perl -ne 'print if /\[(ok|warn|error)\]|CHANGED|  [a-zA-Z]+: /' "$T/out.txt"; }
show() { printf -- '-- config.json --\n'; cat "$HOME/.aitools/config.json"; printf '\n'; }

run "S1 fresh install, bootstrap flags" bash "$W" --repos-path "$HOME/repos" --repo-path "/x/aitools" --drives-json '[]'
show
run "S2 re-run, no flags -> verified" bash "$W"
run "S3 user init explicit alias" bash "$W" --github-user nobul-jose --machine-alias new-mac
show
node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync(process.argv[1]));p.profiles["new-mac"].machine.hostname="zzz";fs.writeFileSync(process.argv[1],JSON.stringify(p,null,2))' "$HOME/repos/aitools-nobul-jose/profile.json"
run "S4 alias kept via config when hostname no longer matches" bash "$W"
node -e 'const fs=require("fs");const f=process.argv[1];const c=JSON.parse(fs.readFileSync(f));delete c.machineAlias;delete c.machineAliasVia;fs.writeFileSync(f,JSON.stringify(c,null,2))' "$HOME/.aitools/config.json"
run "S5 no alias, no match -> ERROR, no fallback" bash "$W"
show
printf '{ "version": 2, "reposPath": "%s", "repoPath": "/x/aitools", ' "$HOME/repos" > "$HOME/.aitools/config.json"
run "S6 corrupt config -> recovered" bash "$W" --machine-alias laptop
show
