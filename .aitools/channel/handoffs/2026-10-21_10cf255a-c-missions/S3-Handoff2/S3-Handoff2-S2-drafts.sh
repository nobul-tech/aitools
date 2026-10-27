#!/usr/bin/env bash
# S3-Handoff2-S2-drafts.sh -- read-only: compare full-file mission drafts with their targets on this worktree (origin/main).
# Usage: bash S3-Handoff2-S2-drafts.sh <worktree>
set -euo pipefail
WT="$1"
M="$WT/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions"
cmp_pair() {
  local draft="$1" target="$2"
  if [ ! -f "$M/$draft" ]; then
    printf 'NO-DRAFT\t%s\n' "$draft"; return 0
  fi
  if [ ! -f "$WT/$target" ]; then
    printf 'TARGET-MISSING\t%s\t->\t%s\n' "$draft" "$target"; return 0
  fi
  local n
  n=$(git -C "$WT" diff --no-index --numstat -- "$M/$draft" "$WT/$target" | perl -ane 'print "+$F[0]/-$F[1]"') || true
  if [ -z "$n" ]; then
    printf 'IDENTICAL\t%s\t->\t%s\n' "$draft" "$target"
  else
    printf 'DIFFERS(%s)\t%s\t->\t%s\n' "$n" "$draft" "$target"
  fi
}
cmp_pair S3-ScratchRule/S3-ScratchRule-drafts/shared/rules/scratch.md shared/rules/scratch.md
cmp_pair S3-HooksFix/S3-HooksFix-drafts/dot-claude/rules/hook-rollout.md .claude/rules/hook-rollout.md
cmp_pair S3-HooksFix/S3-HooksFix-drafts/dot-cursor/rules/hook-rollout.mdc .cursor/rules/hook-rollout.mdc
cmp_pair S3-HooksFix/S3-HooksFix-drafts/shared/rules/hook-lifecycle.md shared/rules/hook-lifecycle.md
cmp_pair S3-Hooks/S3-Hooks-drafts/dot-claude/rules/hook-lifecycle.md .claude/rules/hook-lifecycle.md
cmp_pair S3-Hooks/S3-Hooks-drafts/dot-claude/rules/hook-rollout.md .claude/rules/hook-rollout.md
cmp_pair S3-SpecRewrite/S3-SpecRewrite-drafts/reference/managed-file-deployment.md reference/managed-file-deployment.md
cmp_pair S3-SpecRewrite/S3-SpecRewrite-drafts/dot-claude/rules/managed-file-deployment.md .claude/rules/managed-file-deployment.md
cmp_pair S3-SpecRewrite/S3-SpecRewrite-drafts/dot-claude/rules/interactive-menus.md .claude/rules/interactive-menus.md
cmp_pair S3-SpecRewrite/S3-SpecRewrite-drafts/dot-cursor/rules/managed-file-deployment.mdc .cursor/rules/managed-file-deployment.mdc
cmp_pair S3-SpecRewrite/S3-SpecRewrite-drafts/dot-cursor/rules/interactive-menus.mdc .cursor/rules/interactive-menus.mdc
cmp_pair S3-RegCC/S3-RegCC-drafts/reference/evaluations/claude-code-macos-2026-10-21.md reference/evaluations/claude-code-macos-2026-10-21.md
cmp_pair S3-GateFix/S3-GateFix-drafts/reference/tool-support-decision-tree.md reference/tool-support-decision-tree.md
cmp_pair S3-GateFix/S3-GateFix-drafts/shared/skills/tool-adopt/SKILL.md shared/skills/tool-adopt/SKILL.md
cmp_pair S3-Gate/S3-Gate-drafts/reference/framework-tool-lifecycle.md reference/framework-tool-lifecycle.md
cmp_pair S3-Gate/S3-Gate-drafts/dot-cursor/rules/managed-file-deployment.mdc .cursor/rules/managed-file-deployment.mdc
cmp_pair S3-Gate/S3-Gate-drafts/dot-cursor/rules/tool-lifecycle.mdc .cursor/rules/tool-lifecycle.mdc
cmp_pair S3-Gate/S3-Gate-drafts/dot-cursor/rules/interactive-menus.mdc .cursor/rules/interactive-menus.mdc
cmp_pair S3-Gate/S3-Gate-drafts/dot-claude/rules/git-safety.md .claude/rules/git-safety.md
cmp_pair S3-Gate/S3-Gate-drafts/dot-claude/skills/tool-registry/SKILL.md .claude/skills/tool-registry/SKILL.md
cmp_pair S3-Gate/S3-Gate-drafts/dot-claude/skills/tool-eval/SKILL.md .claude/skills/tool-eval/SKILL.md
cmp_pair S3-Gate/S3-Gate-drafts/dot-claude/skills/tool-adopt/SKILL.md shared/skills/tool-adopt/SKILL.md
cmp_pair S3-H-Cursor/S3-H-Cursor-drafts/reference/tool-ops-cursor.md reference/tool-ops-cursor.md
cmp_pair S3-H-Core/S3-H-Core-drafts/reference/managed-file-deployment.md reference/managed-file-deployment.md
cmp_pair S3-H-MDM/S3-H-MDM-drafts/dot-claude/rules/deploy-paths.md .claude/rules/deploy-paths.md
cmp_pair S3-M3-Docs/S3-M3-Docs-drafts/reference/user-repo.md reference/user-repo.md
cmp_pair S3-Profile/S3-Profile-drafts/reference/user-repo.md reference/user-repo.md
