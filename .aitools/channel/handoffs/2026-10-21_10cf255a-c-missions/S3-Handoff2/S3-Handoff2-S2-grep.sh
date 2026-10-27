#!/usr/bin/env bash
# S3-Handoff2-S2-grep.sh -- read-only probes: does draft NEW text appear in targets on this worktree?
# Usage: bash S3-Handoff2-S2-grep.sh <worktree>
set -euo pipefail
WT="$1"
probe() {
  local label="$1" pattern="$2" file="$3"
  local hits
  hits=$(grep -cF -- "$pattern" "$WT/$file" 2>/dev/null) || hits=0
  printf '%s\t%s\t%s\n' "$label" "$hits" "$file"
}
probe "M3Docs r1 plans edit1" 'machine profiles are keyed by them' plans/tool-support-and-machine-profile.md
probe "M3Docs r1 plans edit3" 'Registration never overwrites another machine' plans/tool-support-and-machine-profile.md
probe "M3Docs r2 glossary" 'Since profile.json revision 2.2' registries/glossary.json
probe "M3Docs r3 user-repo 2.2" 'revision 2.2' reference/user-repo.md
probe "M3Docs r3 user-repo intent" '**Intent**' reference/user-repo.md
probe "M3Docs r5 config intent machineId" 'machineId, and machineAlias as a display value' scripts/setup-user-config.sh
probe "M3Docs r6 writer intent" 'then pass --machine-id' scripts/setup-user-config.sh
probe "M3Docs r9 mfd rule fallback text" 'first profile' .claude/rules/managed-file-deployment.md
probe "M3Docs r12 claude-shared USER_REPO_PATH" 'USER_REPO_PATH' shared/claude-shared.md
probe "M3Docs r14 deploy-paths resolver embed" 'aitools-profile' .claude/rules/deploy-paths.md
probe "H-MDM deploy-paths MDM run order" 'MDM run order' .claude/rules/deploy-paths.md
probe "M3Docs r16 logging library-style" 'Library-style tools' reference/logging.md
probe "M3Docs r15 ssd jsonl_record" 'jsonl_record' reference/script-standards-detail.md
probe "GateFix R16 ssd exit 2" 'deliberate exit 2' reference/script-standards-detail.md
probe "S3-H-Core ssd harness files" 'harness files' reference/script-standards-detail.md
probe "SourceTruth cfs backup draft" 'Backup failures are non-fatal for whole-directory backups' .claude/rules/config-file-safety.md
probe "cfs old backup text" 'Backup failures are non-fatal (warn and proceed)' .claude/rules/config-file-safety.md
probe "R21 cfs setup-user-config example" 'setup-user-config' .claude/rules/config-file-safety.md
probe "H-Cursor tool-ops.json cursor key" '"cursor"' registries/tool-ops.json
probe "H-ToolOps intent draft applied?" 'Per-tool ops references' .claude/skills/tool-ops/SKILL.md
probe "R15 git-safety generated/" 'generated/' .claude/rules/git-safety.md
probe "R2 tool-lifecycle update policy" 'update policy' .claude/rules/tool-lifecycle.md
probe "R2 tool-lifecycle decision tree" 'tool-support-decision-tree' .claude/rules/tool-lifecycle.md
probe "R8 sources-of-truth intent" '**Intent**' .claude/rules/sources-of-truth.md
probe "R11 registry schema 1.1" '"schemaVersion": "1.1"' registries/tool-registry.json
probe "R11 registry updateChannel" 'updateChannel' registries/tool-registry.json
probe "R12 framework-registry tool lifecycle" 'tool-support-decision-tree' registries/framework-registry.json
probe "R19 claude-shared xplat line" 'aitools user init' shared/claude-shared.md
probe "R25 setup-go intent" 'Intent:' scripts/setup-go.sh
probe "R22 profile intent migrate" 'migrate` subcommand' scripts/aitools-profile.sh
probe "aitools-json.pl DRAFT intent" 'DRAFT' scripts/aitools-json.pl
probe "lib relay Intent" 'Intent: give every parent script' scripts/aitools-lib.sh
probe "M3Docs r17 tool-adopt" 'user-repo.md' shared/skills/tool-adopt/SKILL.md
probe "tool-ops-claude-code #25 SendMessage" 'SendMessage' reference/tool-ops-claude-code.md
probe "delegate skill aitool-ops refs" '/aitool-ops' shared/skills/delegate/SKILL.md
probe "x-platform C:\\repos" 'C:\repos' .claude/rules/cross-platform.md
probe "hook-rollout sed single-line" 'single-line' .claude/rules/hook-rollout.md
probe "agentic-standards managed-file section" 'Managed-file review choices' .claude/rules/agentic-standards.md
