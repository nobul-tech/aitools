#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools

echo "=== running build-deploy.sh ==="
bash scripts/build-deploy.sh > /tmp/build-deploy.log 2>&1
echo "exit: $?"
echo "--- tail ---"; tail -8 /tmp/build-deploy.log

# Resolve deploy dir (userRepoPath/deploy)
URP=$(grep -o '"userRepoPath"[^,}]*' "$HOME/.aitools/config.json" | head -1 | sed 's/.*: *"//; s/"$//')
DD="$URP/deploy"
echo ""
echo "=== generated setup-user-settings in deploy? ==="
ls -la "$DD/setup-user-settings.sh" "$DD/setup-user-settings.ps1" 2>&1

echo ""
echo "=== deploy/setup-user-settings.sh: has sync_managed_json inlined + parses? ==="
grep -cE 'sync_managed_json\(\)|prompt_json_field_review\(\)' "$DD/setup-user-settings.sh" 2>/dev/null | xargs echo "lib fns defined (expect >=2):"
bash -n "$DD/setup-user-settings.sh" && echo "OK bash -n deploy settings.sh" || echo "FAIL parse deploy settings.sh"

echo ""
echo "=== deploy/setup-user-hooks.sh: prefs gone + parses? ==="
grep -nE 'autoMemory|alwaysThinking|effortLevel|claude preferences|sortKeys\(settings\), null' "$DD/setup-user-hooks.sh" || echo "(no pref refs / no sortKeys write -- good)"
bash -n "$DD/setup-user-hooks.sh" && echo "OK bash -n deploy hooks.sh" || echo "FAIL parse deploy hooks.sh"

echo ""
echo "=== pwsh parse generated ps1 deploy scripts ==="
for f in setup-user-settings.ps1 setup-user-hooks.ps1 setup-user-mcp.ps1; do
  if pwsh -NoProfile -Command "\$e=\$null;\$null=[System.Management.Automation.Language.Parser]::ParseFile('$DD/$f',[ref]\$null,[ref]\$e);if(\$e){\$e;exit 1}" 2>/dev/null; then echo "OK $f"; else echo "FAIL $f"; fi
done