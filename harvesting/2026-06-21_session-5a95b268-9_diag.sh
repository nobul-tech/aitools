#!/usr/bin/env bash
set -uo pipefail

echo "=== settings.json SessionEnd hook config ==="
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    d = json.load(open(p))
    print(json.dumps(d.get("hooks", {}).get("SessionEnd", {}), indent=2))
except Exception as e:
    print("(could not parse:", e, ")")
PY

echo
echo "=== recent session-archive.log (bash fallback logger) ==="
tail -25 "$HOME/.aitools/logs/session-archive.log" 2>/dev/null || echo "(none)"

echo
echo "=== recent ait-harvest.log ==="
tail -50 "$HOME/.aitools/logs/ait-harvest.log" 2>/dev/null || echo "(none)"
