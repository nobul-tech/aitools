#!/bin/bash
set -euo pipefail
# Remove ephemeral files that were recovered but don't belong in harvesting/
# These are: commit messages, test scripts, utility scripts, preapproval markers

HARVEST_DIR="/Users/pepe/repos/aitools/harvesting"
removed=0

for f in \
  "$HARVEST_DIR/2026-03-19_.write-preapproved" \
  "$HARVEST_DIR/2026-03-19_audit-rule-crossrefs.py" \
  "$HARVEST_DIR/2026-03-19_audit-rule-enforcement.py" \
  "$HARVEST_DIR/2026-03-19_commit-msg-close.txt" \
  "$HARVEST_DIR/2026-03-19_commit-msg-final.txt" \
  "$HARVEST_DIR/2026-03-19_commit-msg-v0623.txt" \
  "$HARVEST_DIR/2026-03-19_commit-msg-v0624.txt" \
  "$HARVEST_DIR/2026-03-19_commit-msg-v0625.txt" \
  "$HARVEST_DIR/2026-03-19_commit-msg-v0626.txt" \
  "$HARVEST_DIR/2026-03-19_commit-msg.txt" \
  "$HARVEST_DIR/2026-03-19_extract-user-msgs.pl" \
  "$HARVEST_DIR/2026-03-19_run-step16.sh" \
  "$HARVEST_DIR/2026-03-19_scan-json-refs.py" \
  "$HARVEST_DIR/2026-03-19_search-mission.sh" \
  "$HARVEST_DIR/2026-03-19_test-ambiguous.sh" \
  "$HARVEST_DIR/2026-03-19_test-ambiguous2.sh" \
  "$HARVEST_DIR/2026-03-19_test-brace-expand.sh" \
  "$HARVEST_DIR/2026-03-19_test-braces.sh" \
  "$HARVEST_DIR/2026-03-19_test-heredoc.sh" \
  "$HARVEST_DIR/2026-03-19_test-hook-violations.sh" \
  "$HARVEST_DIR/2026-03-19_test-paste-exit.sh" \
  "$HARVEST_DIR/2026-03-19_test-paste-pipefail.sh" \
  "$HARVEST_DIR/2026-03-19_test-procsub-debug.sh" \
  "$HARVEST_DIR/2026-03-19_test-procsub-heredoc.sh" \
  "$HARVEST_DIR/2026-03-19_test-redirect.sh" \
  "$HARVEST_DIR/2026-03-19_test-redirect2.sh" \
  "$HARVEST_DIR/2026-03-19_test-redirect3.sh" \
  "$HARVEST_DIR/2026-03-19_test-remaining-hooks.sh" \
  "$HARVEST_DIR/2026-03-19_test-sete-procsub.sh" \
  "$HARVEST_DIR/2026-03-19_test-sete-procsub2.sh" \
  "$HARVEST_DIR/2026-03-19_test-step21-exact.sh" \
  "$HARVEST_DIR/2026-03-19_test-step21.sh" \
  "$HARVEST_DIR/2026-03-19_verify-all.py" \
  "$HARVEST_DIR/2026-03-19_verify-hooks.sh" \
  "$HARVEST_DIR/2026-03-19_verify-mcp.py" \
  "$HARVEST_DIR/2026-03-19_verify-settings.py"
do
  if [ -f "$f" ]; then
    rm "$f"
    removed=$((removed + 1))
    echo "Removed: $(basename "$f")"
  fi
done

echo ""
echo "Removed $removed ephemeral files from harvesting/"
