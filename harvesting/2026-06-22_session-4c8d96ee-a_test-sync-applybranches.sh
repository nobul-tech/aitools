#!/usr/bin/env bash
# Test adopt/skip apply branches by running the REAL embedded node script
# (extracted from aitools-lib.sh between the SYNC_NODE_EOF markers) with
# crafted choices -- no tty needed, no logic duplication.
set -uo pipefail
cd /Users/new-jose/repos/aitools
T=$(mktemp -d); NS="$T/sync.js"
pass=0; fail=0
chk() { if [ "$2" = "$3" ]; then echo "PASS: $1"; pass=$((pass+1)); else echo "FAIL: $1 (exp $2 got $3)"; fail=$((fail+1)); fi; }
jget() { node -e "const o=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));let v=o;for(const k of process.argv[2].split('.')){if(k==='')continue;v=(v==null)?undefined:v[k];}const s=JSON.stringify(v);process.stdout.write(s===undefined?'undefined':s);" "$1" "$2"; }

# Extract embedded node script
perl -ne 'print if /<<.SYNC_NODE_EOF.\s*$/../^SYNC_NODE_EOF\s*$/' scripts/aitools-lib.sh \
  | perl -ne 'next if /<<.SYNC_NODE_EOF.\s*$/; next if /^SYNC_NODE_EOF\s*$/; print' > "$NS"
echo "extracted node script lines: $(wc -l < "$NS")"

cat > "$T/live.json" <<'EOF'
{ "theme": "light", "model": "A", "permissions": {"defaultMode":"default"} }
EOF
cat > "$T/profile.json" <<'EOF'
{ "claude": {"settings": {"theme":"dark","model":"B","permissions":{"defaultMode":"default","deny":["PROFILE_ONLY"]}}} }
EOF

node "$NS" plan "$T/live.json" "$T/profile.json" "claude.settings" "hooks" "" "$T/plan.json" > "$T/dec.tsv" 2>/dev/null
echo "--- decisions ---"; cat "$T/dec.tsv"

# Craft choices: theme->adopt, model->skip, PROFILE_ONLY->adopt
{
  printf 'theme\tadopt\n'
  printf 'model\tskip\n'
  printf 'permissions.deny PROFILE_ONLY\tadopt\n'
} > "$T/choices.tsv"

node "$NS" apply "$T/live.json" "$T/profile.json" "claude.settings" "hooks" "" "$T/plan.json" "$T/choices.tsv" >/dev/null 2>&1

echo "--- assertions ---"
chk "theme adopt: live keeps light"           '"light"' "$(jget "$T/live.json" theme)"
chk "theme adopt: profile mirror <- light"    '"light"' "$(jget "$T/profile.json" claude.settings.theme)"
chk "model skip: live stays A"                 '"A"'     "$(jget "$T/live.json" model)"
chk "model skip: profile stays B"              '"B"'     "$(jget "$T/profile.json" claude.settings.model)"
chk "PROFILE_ONLY adopt(live-missing)=dropped" 'undefined-or-empty' "$(v=$(jget "$T/profile.json" claude.settings.permissions.deny); { [ "$v" = 'undefined' ] || [ "$v" = '[]' ]; } && echo 'undefined-or-empty' || echo "$v")"
chk "live still has no deny rule"              'undefined' "$(jget "$T/live.json" permissions.deny)"

echo "===== RESULTS: $pass passed, $fail failed ====="
rm -rf "$T"
[ "$fail" -eq 0 ]