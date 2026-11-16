#!/usr/bin/env bash
# Find callers of harness-db.py verbs and --session across the harness (read-only).
set -euo pipefail
cd /Users/new-jose/repos/aitools
printf '== harness-db verb callers ==\n'
grep -rn -E "harness-db(\.py)?\"? +(mission|log|ol|decision|observation|incident|knowledge|directive|export|process-events|session)" \
    shared .claude scripts reference --include='*.md' --include='*.sh' --include='*.py' --include='*.ps1' \
    | grep -v '^scripts/harness-db.py' | sed -n '1,80p' || true
printf '\n== running-estimate.json references ==\n'
grep -rln "running-estimate.json" shared .claude scripts reference plans --include='*.md' --include='*.sh' --include='*.py' --include='*.ps1' --include='*.json' || true
printf '\n== mission-running-estimate template refs ==\n'
grep -rln "mission-running-estimate" . --include='*.md' --include='*.sh' --include='*.py' --include='*.json' 2>/dev/null | grep -v '^./.scratch' || true
printf '\n== reference/schemas and reference/templates existing ==\n'
ls reference/schemas reference/templates 2>&1 || true
printf '\n== deploy-harness reference copy logic ==\n'
grep -n -E "reference|NO_REVIEW|NoReview|ls-files" scripts/deploy-harness.sh | sed -n '1,40p' || true
