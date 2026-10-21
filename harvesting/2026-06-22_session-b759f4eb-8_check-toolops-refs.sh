#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools

echo "=== tool-ops.json denyRules entries ==="
grep -niE 'permissionPattern|denyRules|MCP\(|claude-code-guide' registries/tool-ops.json 2>/dev/null | head -40 || echo "(none / file path differs)"
echo ""
echo "=== check-post-push.sh references to deny / vercel / webflow / claude-code-guide ==="
grep -niE 'MCP\(vercel\)|MCP\(webflow\)|claude-code-guide|deny' scripts/check-post-push.sh 2>/dev/null | head -25 || echo "(none)"
echo ""
echo "=== aitool-ops reference-card skill: embedded specific deny rules? ==="
grep -niE 'MCP\(vercel\)|MCP\(webflow\)|claude-code-guide|deny rule' shared/skills/aitool-ops/SKILL.md 2>/dev/null | head -25 || echo "(none)"
echo ""
echo "=== tool-ops.json location check ==="
ls -la registries/tool-ops.json 2>/dev/null || find . -name 'tool-ops.json' -not -path '*/.git/*' -not -path '*/harvesting/*' 2>/dev/null | head