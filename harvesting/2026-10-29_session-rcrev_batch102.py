#!/usr/bin/env python3
"""Read-only: count #102 batch entries and show #165/#166 resolution text."""
import json
import subprocess

R = "/Users/new-jose/repos/aitools"
p = ".aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-batch.json"
raw = subprocess.run(["git", "-C", R, "show", f"origin/docs/mf-incidents:{p}"], capture_output=True, text=True, check=True).stdout
d = json.loads(raw)
items = d if isinstance(d, list) else d.get("incidents") or d.get("entries") or []
ids = [e.get("id") for e in items]
print("count", len(items), "min", min(ids), "max", max(ids))
for e in items:
    if e.get("id") in (165, 166):
        print(e["id"], e.get("title"))
        print("  SR:", e.get("suggestedResolution"))
