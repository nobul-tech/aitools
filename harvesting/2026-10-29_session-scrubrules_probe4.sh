#!/usr/bin/env bash
# probe4: follow-ups (read-only)
set -uo pipefail
R=/Users/new-jose/repos/aitools
cd "$R"
sec() { printf '\n===== %s =====\n' "$1"; }

sec "pre-commit step 3 and 10 bodies"
sed -n '95,122p' scripts/check-pre-commit.sh
sed -n '215,236p' scripts/check-pre-commit.sh

sec "setup-user-claude deploy_managed_file calls"
grep -n 'deploy_managed_file' scripts/setup-user-claude.sh | head
grep -n 'deploy_managed_file()' scripts/aitools-lib.sh
grep -n -A30 '^deploy_managed_file()' scripts/aitools-lib.sh | grep -n 'local\|\$[0-9]' | head -20

sec "setup-user-skills targets"
sed -n '1,30p' scripts/setup-user-skills.sh

sec "who calls _audit_manifest / prune"
grep -n '_audit_manifest(\|def cmd_\|"audit"\|add_parser' scripts/ait-harvest.py | head -20
grep -n 'ait-harvest.py\|HELPER"' shared/hooks/session-catchup.sh shared/hooks/harvest-session.sh | head

sec "pre-push step 10 user repo push"
sed -n '237,275p' scripts/check-pre-push.sh

sec "dotprofile non-main push error (#165)"
grep -n 'not on main\|non-main\|branch.*main' scripts/aitools-lib.sh | head -10

sec "check-post-push 29/30 exist in ps1"
grep -nE '"(29|30)"' scripts/check-post-push.ps1 | head -4

sec "CLAUDE.md channel exception text"
sed -n '75,94p' CLAUDE.md

sec "delegation-duty-guard events"
grep -n 'events.jsonl\|current-session' shared/hooks/delegation-duty-guard.sh shared/hooks/standing-order-guard.sh | head

sec "standing-order-guard semicolon exemptions"
sed -n '178,188p' shared/hooks/standing-order-guard.sh

sec "hook-lifecycle deploy note in shared/rules"
sed -n '1,30p' shared/rules/hook-lifecycle.md

sec "D-DEL5 in delegation rule (dotprofile)"
grep -rn 'D-DEL5' /Users/new-jose/.claude/rules/delegation.md shared/skills/delegate/SKILL.md 2>&1 | head
ls /Users/new-jose/repos 2>&1 | head -20

sec "reference/cross-platform-detail supported section"
grep -n -A25 'Supported platforms and environments' reference/cross-platform-detail.md | head -45

sec "rules frontmatter paths in md (which lack)"
for f in .claude/rules/*.md; do printf '%s: ' "$f"; head -1 "$f"; done
