#!/bin/bash
set -euo pipefail
# Check knowledge DB age and recent harvesting artifact counts

echo "=== Knowledge DB ==="
stat -f "modified: %Sm" -t "%Y-%m-%d %H:%M" /Users/pepe/.aitools/knowledge.db
stat -f "size: %z bytes" /Users/pepe/.aitools/knowledge.db

echo ""
echo "=== Harvesting artifacts by date ==="
echo "2026-03-25 (today):"
ls -1 /Users/pepe/repos/aitools/harvesting/ | grep "^2026-03-25" | wc -l | tr -d ' '

echo "2026-03-24:"
ls -1 /Users/pepe/repos/aitools/harvesting/ | grep "^2026-03-24" | wc -l | tr -d ' '

echo "2026-03-23:"
ls -1 /Users/pepe/repos/aitools/harvesting/ | grep "^2026-03-23" | wc -l | tr -d ' '

echo "Total:"
ls -1 /Users/pepe/repos/aitools/harvesting/ | wc -l | tr -d ' '

echo ""
echo "=== harvest-manifest.json status ==="
git -C /Users/pepe/repos/aitools diff --stat harvesting/harvest-manifest.json
