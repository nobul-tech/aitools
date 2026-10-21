#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools
pass=0; fail=0

echo "=== tool-ops.json valid JSON + denyRules gone + hook kept ==="
if node -e "JSON.parse(require('fs').readFileSync('registries/tool-ops.json','utf8'))" 2>/dev/null; then echo "PASS valid JSON"; pass=$((pass+1)); else echo "FAIL invalid JSON"; fail=$((fail+1)); fi
node -e '
const o=JSON.parse(require("fs").readFileSync("registries/tool-ops.json","utf8"));
const cc=o.tools["claude-code"];
console.log("denyRules array present:", "denyRules" in cc, "(expect false)");
console.log("governanceModes.denyRules present:", "denyRules" in cc.governanceModes, "(expect false)");
console.log("hook still present:", cc.hooks && cc.hooks.some(h=>h.script==="block-claude-code-guide.sh"), "(expect true)");
console.log("verification still present:", cc.verifications && cc.verifications.length>0, "(expect true)");
'

echo ""
echo "=== re-run build-deploy (propagate claude-shared.md / CLAUDE.md doc changes) ==="
bash scripts/build-deploy.sh > /tmp/bd2.log 2>&1
echo "exit: $?"
tail -2 /tmp/bd2.log

echo ""
echo "=== deny rules gone from regenerated deploy/setup-user-mcp.* ==="
URP=$(grep -o '"userRepoPath"[^,}]*' "$HOME/.aitools/config.json" | head -1 | sed 's/.*: *"//; s/"$//')
grep -c 'MCP(vercel)\|MCP(webflow)\|Agent(claude-code-guide)' "$URP/deploy/setup-user-mcp.sh" 2>/dev/null | xargs echo "deny refs in deploy mcp.sh (expect 0):"

echo ""
echo "=== RESULTS: $pass passed, $fail failed (see inline expects above) ==="