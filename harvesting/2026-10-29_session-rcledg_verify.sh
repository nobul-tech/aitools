#!/usr/bin/env bash
# Batch of git-grep probes on origin/main for marker triage.
set -euo pipefail
R=/Users/new-jose/repos/aitools
g() { local label="$1" pat="$2"; shift 2; printf '\n=== %s  [%s]\n' "$label" "$pat"; git -C "$R" grep -n -E -e "$pat" origin/main -- "$@" | cut -c1-260 || printf 'NO MATCH\n'; }
g a-readme-mdm "deploy-harness|MDM" README.md
g c-abort-text "stop the run" scripts/aitools-lib.sh scripts/aitools-lib.ps1 .claude/rules/interactive-menus.md reference/managed-file-deployment.md
g d1-userinit-hooks "setup-user-hooks" scripts/aitools scripts/aitools.ps1
g d2-bootstrap "powershell|pwsh" scripts/bootstrap.ps1
g d3-gitbash "Git\\\\bin\\\\bash|Git/bin/bash" scripts/aitools.ps1 scripts/setup-bash.ps1
g f1-uptodate "up.to.date" scripts/aitools-install.sh scripts/aitools-install.ps1
g f2-claude-auth "claude auth|auth status" scripts/aitools-install.sh scripts/aitools-install.ps1
g g-catchup-trunc "\[:10\]|10\]" scripts/ait-harvest.py
g h-bare-read "read -r [a-z_]+ < /dev/tty" scripts shared
g i1-merge-reason "AI_REJECT_REASON" scripts/aitools-lib.sh
g i2-step30 "w\[\\\\w-\]" scripts/check-post-push.sh scripts/check-post-push.ps1
g j1-claude-rules-adopt "git -C .* (commit|push)|git_commit_push|dotprofile_commit" scripts/setup-user-claude.sh
g j2-skills-adopt "claude/skills" scripts/setup-user-skills.sh
g j3-mcp-isolation "MCP server isolation|Deployment pattern updates" .claude reference .cursor shared
g j4-cfs-both "both sides differ" .claude/rules/config-file-safety.md
g k1-agents "AGENTS.md" scripts/aitools scripts/aitools-install.sh scripts/aitools-install.ps1 scripts/aitools.ps1
g k2-backupdir "\*\.md" scripts/aitools-lib.sh
g k3-cursorprac "Not file-accessible|SQLite" reference/cursor-practices.md
g l1-lib-twice "inline_lib_bash|inline_lib_ps1" scripts/build-deploy.sh
g l2-size "200000|200 KB|size gate|wc -c" scripts/build-deploy.sh
g l3-trap "trap " scripts/build-deploy.sh
g m-fanout-claims "fans? out|fan-out" .claude/rules/managed-file-deployment.md reference/harness.md
g n1-claim "--claim" scripts/aitools scripts/aitools-profile.sh scripts/aitools-profile.ps1
g n2-rebuilt "Rebuilt" scripts/aitools scripts/aitools.ps1
g o-exc-hdr "hostname only or not at all" scripts/aitools-lib.sh scripts/aitools-lib.ps1
g p-allow "tool-ops-cursor" scripts/check-path-refs-allow.txt
g q-addsource "\*\.bak\.\*|-like" scripts/deploy-harness.sh scripts/deploy-harness.ps1
g r-relay-exit2 "failed \(exit" scripts/aitools-lib.sh scripts/aitools-lib.ps1
g t-handoff-step5 "schwerpunkt" shared/skills/handoff/SKILL.md
g u-removed-outcome "removed" scripts/aitools-lib.sh
g w-workspace ".aitools/scratch|deploy-state" .claude/rules/aitools-workspace.md
g x-gitbash-only "always uses Git Bash" shared/claude-shared.md reference/tool-ops-claude-code.md
g y-tooops-ver "Current version" reference/tool-ops-claude-code.md
g z-profile-term "keyed by machine alias" registries/glossary.json
