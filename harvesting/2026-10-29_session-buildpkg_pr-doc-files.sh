#!/bin/bash
# List doc/script files owned by open PRs (number<TAB>path).
set -euo pipefail
gh pr list -R nobul-tech/aitools --state open --limit 50 --json number,files \
  --jq '.[] | .number as $n | .files[] | select(.path | test("^(README.md|CLAUDE.md|\\.claude/rules|\\.cursor/rules|reference/|shared/|ROADMAP|plans/|scripts/|registries/|\\.github/)")) | "\($n)\t\(.path)"' | sort -k2
