"""Print selected incident fields from the origin/main copy (read-only). Usage: python3 show-incidents.py id id ..."""
import json
import sys

path = "/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S4-Review/S4-Review-scratch/incidents-main.json"
d = json.load(open(path))
want = {int(a) for a in sys.argv[1:]}
for i in d["incidents"] + d["closed"]:
    if i.get("id") in want:
        print(f"== #{i['id']} [{i.get('status')}/{i.get('severity')}] {i.get('title')}")
        for k in ("affected", "linked", "observation", "suggestedResolution", "closedIn"):
            v = i.get(k)
            if v:
                s = json.dumps(v) if not isinstance(v, str) else v
                print(f"  {k}: {s[:700]}")
