#!/usr/bin/env bash
# R6 verification on the export: plan grep, byte-identity with claude-shared, diff
set -euo pipefail
T=/Users/new-jose/repos/aitools/.scratch/session-rcbar/tree
printf 'plan verify (expect 0): '
grep -c "C:\\\\repos" "$T/shared/cursor-rules/user-rules.md" || true
L=$(grep -F 'Projects live in git repos under' "$T/shared/claude-shared.md")
printf 'byte-identical with claude-shared line: '
grep -c -x -F -- "$L" "$T/shared/cursor-rules/user-rules.md" || true
printf 'plan NEW literal (no trailing backslash) would match claude-shared: '
grep -c -x -F -- '- Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos` (Windows)' "$T/shared/claude-shared.md" || true
git -C "$T" diff -- shared/cursor-rules/user-rules.md
