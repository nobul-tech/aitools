"""Search incident text (all fields) for keywords; prints id + title per hit. Usage: python3 grep-incidents.py kw1 kw2 ..."""
import json
import sys

path = "/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-scratch/incidents-main.json"
d = json.load(open(path))
items = d["incidents"] + d["closed"]
for kw in sys.argv[1:]:
    hits = [i for i in items if kw.lower() in json.dumps(i).lower()]
    print(f"[{kw}] " + "; ".join(f"#{i['id']} {i.get('title', '')[:70]}" for i in hits))
