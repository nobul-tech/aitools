"""incident-ids.py -- print the max incident id on main and the approved batch's ids (scratch)."""
import json

R = "/Users/new-jose/repos/aitools"
reg = json.load(open(R + "/registries/incidents.json"))
print("registry max id:", max(i["id"] for i in reg["incidents"] + reg["closed"]))
b = json.load(open(R + "/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-batch.json"))
if isinstance(b, dict):
    print("batch keys:", list(b.keys()))
    entries = b.get("incidents") or b.get("entries") or []
else:
    entries = b
print("batch ids:", [e["id"] for e in entries])
print("batch fields:", list(entries[0].keys()) if entries else None)
