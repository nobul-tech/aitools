#!/usr/bin/env bash
# sweep2.sh - second keyword sweep (pre-push, rules dirs, deploy locations) on origin/main (read-only)
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
REF=origin/main
OUT=/Users/new-jose/repos/aitools/.scratch/session-rcdocs/sweep2-hits.txt
: > "$OUT"
PATHS=( '.claude/rules/' '.cursor/rules/' 'reference/' 'shared/claude-shared.md' 'shared/cursor-rules/' 'shared/skills/' 'shared/rules/' '.claude/skills/' 'CLAUDE.md' 'README.md' 'scripts/check-pre-push.sh' 'scripts/check-pre-push.ps1' 'scripts/check-pre-commit.sh' 'scripts/check-pre-commit.ps1' )
PATTERNS=( 'pre-push' 'deploy-relevant' 'deploy/ matches source' 'deploy/ stale' 'stale deploy' '\.aitools/rules' '\.aitools/skills' '\.aitools/hooks' '\.aitools/reference' '\.aitools/registries' 'claude/rules/' 'shared/rules' '\.cursor/rules' 'steps 3\+10' 'step 13' 'aitools/deploy' 'frozen' 'MDM path' 'build-deploy' 'cursor-rule-parity' 'mirrors' )
for p in "${PATTERNS[@]}"; do
  printf '=== %s\n' "$p" >> "$OUT"
  git -C "$REPO" grep -n -I -i -E -e "$p" "$REF" -- "${PATHS[@]}" >> "$OUT" || printf '(no hits)\n' >> "$OUT"
done
wc -l "$OUT"
