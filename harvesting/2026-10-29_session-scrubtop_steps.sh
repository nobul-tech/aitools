#!/usr/bin/env bash
# Count check steps per check script and list aitools subcommands (read-only audit helper)
set -euo pipefail
R=/Users/new-jose/repos/aitools
for f in check-pre-commit check-pre-push check-post-push; do
  printf '== %s.sh step headers ==\n' "$f"
  grep -n -E '^\s*(step_begin|step_header|step_start|begin_step|STEP|# ---? *Step|# Step)' "$R/scripts/$f.sh" | head -60 || printf '(none matched)\n'
done
printf '== tiers in post-push ==\n'
grep -n -E 'always|extensive|TIER' "$R/scripts/check-post-push.sh" | head -40 || true
printf '== aitools subcommands ==\n'
grep -n -E '^\s+[a-z|\-]+\)\s*$|^\s+"?[a-z-]+"?\)' "$R/scripts/aitools" | head -80 || true
