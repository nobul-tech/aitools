#!/usr/bin/env bash
# sweep.sh - grep the deployment doc set on origin/main for audit keywords (read-only)
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
REF=origin/main
OUT=/Users/new-jose/repos/aitools/.scratch/session-rcdocs/sweep-hits.txt
: > "$OUT"
PATHS=( '.claude/rules/' '.cursor/rules/' 'reference/' 'shared/claude-shared.md' 'shared/cursor-rules/' 'shared/skills/' 'shared/rules/' '.claude/skills/' 'CLAUDE.md' 'README.md' )
PATTERNS=( 'fan-out' 'fans out' 'fan out' 'aitools/rules' 'step 7' 'Step 7' 'deploy-harness' 'abort' 'exit 2' 'stop the run' 'only writer' 'sole writer' 'single config writer' 'parity' 'twin' 'only when .*shared' 'shared/ change' 'shared/ is modified' 'deploy drift' 'deploy-drift' 'user init' 'setup-user-config' )
for p in "${PATTERNS[@]}"; do
  printf '=== %s\n' "$p" >> "$OUT"
  git -C "$REPO" grep -n -I -i -e "$p" "$REF" -- "${PATHS[@]}" >> "$OUT" || printf '(no hits)\n' >> "$OUT"
done
wc -l "$OUT"
