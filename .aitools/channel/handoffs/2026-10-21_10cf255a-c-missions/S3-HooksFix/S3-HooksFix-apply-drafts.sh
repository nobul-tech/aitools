#!/usr/bin/env bash
# S3-HooksFix-apply-drafts.sh -- copy the S3-HooksFix rule drafts to their live
# locations once the commander has approved this exact content.
# Usage: S3-HooksFix-apply-drafts.sh <aitools-checkout-root>
# Writes: .claude/rules/hook-rollout.md, .cursor/rules/hook-rollout.mdc,
#         shared/rules/hook-lifecycle.md (user-level; no deploy path yet).
set -euo pipefail
ROOT="${1:?usage: $0 <aitools-checkout-root>}"
D="$ROOT/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-HooksFix/S3-HooksFix-drafts"
for pair in \
    "dot-claude/rules/hook-rollout.md:.claude/rules/hook-rollout.md" \
    "dot-cursor/rules/hook-rollout.mdc:.cursor/rules/hook-rollout.mdc" \
    "shared/rules/hook-lifecycle.md:shared/rules/hook-lifecycle.md"; do
    src="$D/${pair%%:*}"
    dst="$ROOT/${pair##*:}"
    [ -s "$src" ] || { echo "ERROR: missing draft $src" >&2; exit 1; }
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "wrote $dst"
done
git -C "$ROOT" status --short .claude/rules .cursor/rules shared/rules
