"""Print incidents 172/173 as of a git rev, and as now. Usage: python old-incident.py <wt> <rev>"""
import json
import subprocess
import sys

wt, rev = sys.argv[1], sys.argv[2]
raw = subprocess.run(["git", "-C", wt, "show", f"{rev}:registries/incidents.json"], capture_output=True, check=True).stdout
old = json.loads(raw.decode("utf-8"))
now = json.load(open(f"{wt}/registries/incidents.json", encoding="utf-8"))
for label, d in (("old", old), ("now", now)):
    for arr in ("incidents", "closed"):
        for i in d[arr]:
            if i["id"] in (172, 173):
                print(label, arr, i["id"], json.dumps({k: i.get(k) for k in ("title", "severity", "status", "closedIn", "closedDate", "updated")}, ensure_ascii=True))
print("max id now", max(i["id"] for i in now["incidents"] + now["closed"]), "open", len(now["incidents"]), "closed", len(now["closed"]))
