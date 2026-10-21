#!/usr/bin/env bash
# test-resolver.sh -- read-only tests of the drafted aitools-profile.js against an
# isolated HOME (copies of profile.json). Never writes ~/.aitools or the dotprofile.
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
JS="$M/S5-Profile-drafts/scripts/aitools-profile.js"
T="$M/tests/run"
rm -rf "$T"
mkdir -p "$T/home/.aitools" "$T/home/repos/aitools-nobul-jose"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$T/home/repos/aitools-nobul-jose/profile.json"
P="$T/home/repos/aitools-nobul-jose/profile.json"
C="$T/home/.aitools/config.json"
run() { local name="$1"; shift; local rc=0; local out; out=$(HOME="$T/home" "$@" 2>&1) || rc=$?; printf '== %s (exit %s)\n%s\n' "$name" "$rc" "$out"; }

echo "machine-id: $(node "$JS" machine-id)"
run "T0 real config, read-only resolve" node "$JS" resolve --config /Users/new-jose/.aitools/config.json
printf '{"version":2,"reposPath":"%s/home/repos","repoPath":"/x"}\n' "$T" > "$C"
run "T1 no userRepoPath, no githubUser -> scan" node "$JS" user-repo-path --config "$C" --json
printf '{"version":2,"reposPath":"%s/home/repos","repoPath":"/x","githubUser":"nobul-jose"}\n' "$T" > "$C"
run "T2 convention" node "$JS" user-repo-path --config "$C" --format bash
printf '{"version":2,"reposPath":"%s/home/repos","repoPath":"/x","userRepoPath":"%s/home/repos/aitools-nobul-jose","machineAlias":"new-mac"}\n' "$T" "$T" > "$C"
run "T3 config alias new-mac (no machine.id yet)" node "$JS" resolve --config "$C"
run "T4 register new-mac to tmp" node "$JS" register --profile "$P" --alias new-mac --out "$T/profile.reg.json"
cp "$T/profile.reg.json" "$P"
printf '{"version":2,"reposPath":"%s/home/repos","repoPath":"/x","userRepoPath":"%s/home/repos/aitools-nobul-jose","machineAlias":"laptop"}\n' "$T" "$T" > "$C"
run "T5 machine.id beats stale config alias laptop" node "$JS" resolve --config "$C"
run "T6 derive-config" node "$JS" derive-config --config "$C"
run "T7 override alias unknown -> error" env AITOOLS_MACHINE_ALIAS=nope node "$JS" resolve --config "$C"
cp /Users/new-jose/repos/aitools-nobul-jose/profile.json "$P"
node -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync(process.argv[1]));p.profiles["new-mac"].machine.hostname="zzz";fs.writeFileSync(process.argv[1],JSON.stringify(p))' "$P"
printf '{"version":2,"reposPath":"%s/home/repos","repoPath":"/x","userRepoPath":"%s/home/repos/aitools-nobul-jose"}\n' "$T" "$T" > "$C"
run "T8 no alias, no id, no hostname match -> none (no first-profile fallback)" node "$JS" resolve --config "$C"
run "T9 snapshot" node "$JS" snapshot --profile "$P"
run "T10 claude-code-web env on darwin is forced local" env AITOOLS_ENVIRONMENT=claude-code-web node "$JS" resolve --config "$C"
