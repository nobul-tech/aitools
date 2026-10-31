#!/usr/bin/env bash
# verify-lines.sh - print line numbers for cited anchors on origin/main (read-only)
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
g() { printf '== %s :: %s\n' "$1" "$2"; git -C "$REPO" show "origin/main:$1" | perl -ne "print \"\$.: \$_\" if m{$2}"; }
g .claude/rules/config-file-safety.md 'Settings sync|Inline Node.js'
g .claude/rules/managed-file-deployment.md 'Adding a row|cursor/rules/managed-file'
g reference/harness.md 'No deletion|never commits|fan-out in|tool.s own location|only config'
g scripts/deploy-harness.sh 'deploy_managed_file "\$content"|add_source rules  "dotprofile"'
g shared/skills/tool-adopt/SKILL.md 'deploy list'
g reference/cursor-practices.md 'Cursor project rules mirror|Changing rules|relay-outbound.mdc|cross-platform.mdc'
g scripts/setup-user-cursor.sh 'Preserved: files in'
g scripts/setup-user-claude.sh 'git add "claude/rules|not pushed'
g .claude/rules/interactive-menus.md 'Cross-platform parity|step 29'
git -C "$REPO" show origin/feature/harness-hookin:.claude/rules/interactive-menus.md | perl -ne 'print "hookin $.: $_" if /Despite the menu text|ends .setup-user-settings/'
g reference/logging.md 'deploy-state'
