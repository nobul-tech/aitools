#!/usr/bin/env python3
"""Print status/title of given incident ids (read-only audit helper). Usage: inc.py ID..."""
import json
import sys
from pathlib import Path

d = json.loads(Path("/Users/new-jose/repos/aitools/registries/incidents.json").read_text(encoding="utf-8"))
allx = {i["id"]: ("open-array", i) for i in d["incidents"]}
for c in d["closed"]:
    allx[c["id"]] = ("closed-array", c)
for a in sys.argv[1:]:
    k = int(a)
    if k not in allx:
        print(k, "NOT FOUND")
        continue
    where, i = allx[k]
    print(k, where, i.get("status"), "|", i.get("title"))
