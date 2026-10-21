#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools
pass=0; fail=0
chk(){ if [ "$2" = "$3" ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (exp [$2] got [$3])"; fail=$((fail+1)); fi; }
jget(){ node -e "const o=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));let v=o;for(const k of process.argv[2].split('.')){if(k==='')continue;v=(v==null)?undefined:v[k];}const s=JSON.stringify(v);process.stdout.write(s===undefined?'undefined':s);" "$1" "$2"; }

echo "===== syntax checks ====="
for f in setup-user-settings.sh setup-user-hooks.sh; do
  if bash -n scripts/$f; then echo "PASS bash -n $f"; pass=$((pass+1)); else echo "FAIL bash -n $f"; fail=$((fail+1)); fi
done
for f in setup-user-settings.ps1 setup-user-hooks.ps1; do
  if pwsh -NoProfile -Command "\$e=\$null;\$null=[System.Management.Automation.Language.Parser]::ParseFile('scripts/$f',[ref]\$null,[ref]\$e);if(\$e){\$e;exit 1}" 2>/dev/null; then echo "PASS pwsh parse $f"; pass=$((pass+1)); else echo "FAIL pwsh parse $f"; fail=$((fail+1)); fi
done

echo ""
echo "===== setup-user-settings.sh end-to-end (temp HOME) ====="
H=$(mktemp -d)
mkdir -p "$H/.aitools" "$H/.claude" "$H/dotprofile"
printf '{"version":2,"userRepoPath":"%s/dotprofile"}\n' "$H" > "$H/.aitools/config.json"
printf '{"version":2,"claude":{"autoMemory":false,"alwaysThinking":true,"effortLevel":"high"}}\n' > "$H/dotprofile/profile.json"
cat > "$H/.claude/settings.json" <<EOF
{
  "model": "opus[1m]",
  "theme": "light",
  "autoMemoryEnabled": false,
  "alwaysThinkingEnabled": true,
  "effortLevel": "high",
  "verbose": true,
  "hooks": {"Stop":[{"matcher":"","hooks":[{"type":"command","command":"x"}]}]},
  "permissions": {"defaultMode":"default","deny":["MCP(vercel)","KEEPME"]}
}
EOF
HOME="$H" bash scripts/setup-user-settings.sh </dev/null > "$H/run.log" 2>&1
echo "exit: $?"
chk "S-legacy autoMemory removed"        'undefined' "$(jget "$H/dotprofile/profile.json" claude.autoMemory)"
chk "S-legacy alwaysThinking removed"     'undefined' "$(jget "$H/dotprofile/profile.json" claude.alwaysThinking)"
chk "S-mirror autoMemoryEnabled=false"    'false'     "$(jget "$H/dotprofile/profile.json" claude.settings.autoMemoryEnabled)"
chk "S-mirror effortLevel=high"           '"high"'    "$(jget "$H/dotprofile/profile.json" claude.settings.effortLevel)"
chk "S-mirror theme adopted"              '"light"'   "$(jget "$H/dotprofile/profile.json" claude.settings.theme)"
chk "S-mirror model adopted"              '"opus[1m]"' "$(jget "$H/dotprofile/profile.json" claude.settings.model)"
chk "S-mirror hooks NOT adopted"          'undefined' "$(jget "$H/dotprofile/profile.json" claude.settings.hooks)"
chk "S-mirror deny KEEPME (vercel purged)" '["KEEPME"]' "$(jget "$H/dotprofile/profile.json" claude.settings.permissions.deny)"
chk "S-live deny vercel purged"           '["KEEPME"]' "$(jget "$H/.claude/settings.json" permissions.deny)"
chk "S-live hooks preserved"              '"x"'       "$(jget "$H/.claude/settings.json" hooks.Stop.0.hooks.0.command)"
echo "--- run.log tail ---"; tail -4 "$H/run.log"

echo ""
echo "===== setup-user-settings.sh idempotence (re-run) ====="
before=$(cat "$H/.claude/settings.json"); pbefore=$(cat "$H/dotprofile/profile.json")
HOME="$H" bash scripts/setup-user-settings.sh </dev/null > "$H/run2.log" 2>&1
chk "S2 settings unchanged" "$before" "$(cat "$H/.claude/settings.json")"
chk "S2 profile unchanged" "$pbefore" "$(cat "$H/dotprofile/profile.json")"
rm -rf "$H"

echo ""
echo "===== setup-user-hooks.sh dry-run (hooks-only, prefs removed) ====="
AITOOLS_DRY_RUN=1 bash scripts/setup-user-hooks.sh --dry-run </dev/null > /tmp/hooks-dry.log 2>&1
echo "exit: $?"
echo "--- mentions of autoMemory/effortLevel (should be none) ---"
grep -niE 'autoMemory|alwaysThinking|effortLevel' /tmp/hooks-dry.log || echo "(none)"
grep -qiE 'error|undefined|not defined' /tmp/hooks-dry.log && { echo "FAIL: errors in hooks dry-run"; fail=$((fail+1)); } || { echo "PASS: no errors in hooks dry-run"; pass=$((pass+1)); }

echo ""
echo "===== RESULTS: $pass passed, $fail failed ====="
[ "$fail" -eq 0 ]