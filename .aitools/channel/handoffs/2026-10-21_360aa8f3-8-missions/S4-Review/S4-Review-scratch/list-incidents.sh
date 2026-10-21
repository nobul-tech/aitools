#!/usr/bin/env bash
# List incident id/status/severity/title from origin/main registries/incidents.json (read-only).
set -euo pipefail
out_dir="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-scratch"
git -C /Users/new-jose/repos/aitools show origin/main:registries/incidents.json > "$out_dir/incidents-main.json"
python3 - "$out_dir/incidents-main.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for key in ("incidents", "closed"):
    for i in d.get(key, []):
        print(f"{i.get('id')}\t{key}\t{i.get('status')}\t{i.get('severity')}\t{i.get('title')}")
print("keys:", list(d.keys()))
PY
