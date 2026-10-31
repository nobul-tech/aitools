#!/usr/bin/env python3
"""Read-only: status of selected incident ids in origin/main registries/incidents.json."""
import json
import subprocess

R = "/Users/new-jose/repos/aitools"
raw = subprocess.run(["git", "-C", R, "show", "origin/main:registries/incidents.json"], capture_output=True, text=True, check=True).stdout
d = json.loads(raw)
open_ = {i["id"]: i for i in d.get("incidents", [])}
closed = {i["id"]: i for i in d.get("closed", [])}
allids = list(open_) + list(closed)
print("max id:", max(allids), "open:", len(open_), "closed:", len(closed), "dupes:", len(allids) - len(set(allids)))
for i in [129, 130, 84, 93, 114, 115, 122, 75, 97, 78, 95, 98, 109, 110, 99, 111, 145, 74, 76, 77, 102, 116, 144, 87, 112]:
    if i in open_:
        e = open_[i]
        print(i, "OPEN", e.get("status"), "|", e.get("title", "")[:90], "| CA:", str(e.get("correctiveAction"))[:80])
    elif i in closed:
        print(i, "CLOSED", "|", closed[i].get("title", "")[:90])
    else:
        print(i, "MISSING")
