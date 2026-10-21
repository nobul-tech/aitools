#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools
URP="/Users/new-jose/repos/aitools-nobul-jose"

echo "=== dotprofile CLAUDE.md MCP section ==="
grep -nA9 -iE '## MCP Servers' "$URP/claude/CLAUDE.md" 2>/dev/null | head -16 || echo "(no MCP section / file missing)"
echo ""
echo "=== dotprofile CLAUDE.md prefs ref (setup-user-hooks) ==="
grep -niE 'deployed by .?setup-user-hooks|preferences.*are managed via' "$URP/claude/CLAUDE.md" 2>/dev/null | head || echo "(none)"
echo ""
echo "=== aitool-ops SKILL.md: Deny Rules section ==="
sed -n '55,72p' shared/skills/aitool-ops/SKILL.md
echo ""
echo "=== .cursor/rules/managed-file-deployment.mdc: JSON config row ==="
grep -niE 'JSON config|read-then-merge|field-level|settings.json' .cursor/rules/managed-file-deployment.mdc 2>/dev/null | head
echo ""
echo "=== reference/user-repo.md: section headers (for insertion point) ==="
grep -nE '^#{1,3} ' reference/user-repo.md 2>/dev/null | head -40
echo ""
echo "=== tool-ops tests/expected-behaviors.md: deny-rule cases ==="
grep -niE 'deny rule|cc-deny-guide|denyRules' .claude/skills/tool-ops/tests/expected-behaviors.md 2>/dev/null | head