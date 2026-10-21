#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/.claude"

echo "=== diff: 2026-06-22T001935Z (pre) -> 2026-06-22T002504Z ==="
diff "settings.json.bak.2026-06-22T001935Z" "settings.json.bak.2026-06-22T002504Z" || true
echo ""
echo "=== diff: 2026-06-22T002504Z -> current settings.json ==="
diff "settings.json.bak.2026-06-22T002504Z" "settings.json" || true
echo ""
echo "=== diff: 2026-06-21T203239Z -> 2026-06-22T001935Z (bigger gap) ==="
diff "settings.json.bak.2026-06-21T203239Z" "settings.json.bak.2026-06-22T001935Z" || true
echo ""
echo "=== diff: 2026-06-15T061213Z (old) -> 2026-06-21T203239Z (recent) ==="
diff "settings.json.bak.2026-06-15T061213Z" "settings.json.bak.2026-06-21T203239Z" || true
