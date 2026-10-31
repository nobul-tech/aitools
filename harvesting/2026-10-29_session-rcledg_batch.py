#!/usr/bin/env python3
"""List PR 102 batch entries (id, severity, title, affected)."""
import json, subprocess
REPO = "/Users/new-jose/repos/aitools"
P = ".aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-batch.json"
raw = subprocess.run(["git", "-C", REPO, "show", f"origin/docs/mf-incidents:{P}"], check=True, capture_output=True, text=True).stdout
d = json.loads(raw)
items = d if isinstance(d, list) else d.get("incidents", d.get("entries", []))
if isinstance(d, dict):
    print("top keys", list(d.keys()))
ids = [e["id"] for e in items]
print("count", len(items), "ids", min(ids), "-", max(ids), "contiguous", ids == list(range(min(ids), max(ids) + 1)))
for e in items:
    print(f"#{e['id']} [{e['severity']}] {e['title']}")
    print(f"    affected: {e['affected']}")
json.dump(items, open("/Users/new-jose/repos/aitools/.scratch/session-rcledg/batch102.json", "w"), indent=1)
