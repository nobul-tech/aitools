#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools

echo "=== repo-wide references to the deny rules / vercel-webflow governance ==="
grep -rniE 'MCP\(vercel\)|MCP\(webflow\)|Agent\(claude-code-guide\)|denyRules|deny rules|permissions\.deny|disabled by default' \
  --include='*.sh' --include='*.ps1' --include='*.md' --include='*.json' --include='*.mdc' \
  . 2>/dev/null | grep -vE '^\./\.git/|\.scratch/|settings\.json\.bak|/deploy/' | sort | head -80

echo ""
echo "=== build-deploy.sh: setup-user-mcp generation (extract vs hardcoded) ==="
sed -n '978,1010p' scripts/build-deploy.sh

echo ""
echo "=== build-deploy.sh: setup-user-hooks merge extraction markers ==="
sed -n '1420,1440p' scripts/build-deploy.sh