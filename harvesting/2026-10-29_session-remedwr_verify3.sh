#!/usr/bin/env bash
# Third round of citation spot checks (scratch, read-only).
set -uo pipefail
R=/Users/new-jose/repos/aitools
S=$R/scripts
D=$R/.scratch/session-remedwr/prs
chk() { printf '\n=== %s\n' "$1"; shift; "$@" 2>&1 | head -n 10; }
chk "BD profile snapshot 265-277" grep -n 'aitools-json.pl.*snapshot\|snapshot "\$_urp' $S/build-deploy.sh
chk "BD skills heredoc" grep -n -c '__SKILL_' $S/build-deploy.sh
chk "BD inline_lib_bash def" grep -n '^inline_lib_bash\|^inline_lib_ps1' $S/build-deploy.sh
chk "shared template nobul-jose 29-30" grep -n 'nobul-jose' $R/shared/claude-shared.md
chk "aitool-continue Jose 120" grep -n -i 'jose' $R/shared/skills/aitool-continue/SKILL.md
chk "hooks adopt target 166" sed -n '164,168p' $S/setup-user-hooks.sh
chk "hooks home path 269-277" grep -n "path.join(home" $S/setup-user-hooks.sh
chk "README line 1" grep -n -m1 'Windows 11 and macOS' $R/README.md
chk "logging.md system phase" grep -n -c 'ProgramData\|/Library/Logs' $R/reference/logging.md
chk "tool-ops-cc proxy-injected" grep -n -c 'proxy-injected\|GraphQL' $R/reference/tool-ops-claude-code.md
chk "ssd blog_warn" grep -n 'blog_ok' $R/reference/script-standards-detail.md
chk "cross-platform.md lines" wc -l $R/.claude/rules/cross-platform.md
chk "mdc drift on main" grep -n 'Four script pairs\|steps 3+10' $R/.cursor/rules/deploy-paths.mdc
chk "pr99 mdc drift added" grep -n -E '^\+.*(Four script pairs|steps 3\+10)' $D/pr99.diff
chk "pr99 mdc removed" grep -n -E '^-.*(Four script pairs|steps 3\+10)' $D/pr99.diff
chk "pr106 skip-config" grep -n -E '^\+.*skip-config' $D/pr106.diff
chk "pr100/110 rev-parse added" grep -n -E '^\+.*rev-parse --is-inside-work-tree' $D/pr100.diff $D/pr110.diff $D/pr111.diff
chk "spec for \$3 arg" grep -rln 'Jamf' $R/.claude/rules $R/reference
chk "DH OS guard 44-48" sed -n '42,49p' $S/deploy-harness.sh
chk "lifecycle build-host" grep -n -i 'build-host\|build host' $R/.claude/rules/tool-lifecycle.md
chk "inst unknown option exit" grep -n 'SHOW_HELP' $S/aitools-install.sh
