#!/usr/bin/env python3
"""Dump the claimed-fixed incidents from origin/main incidents.json."""
import json, sys
d = json.load(open("/Users/new-jose/repos/aitools/.scratch/session-rcledg/inc-origin_main.json"))
ids = [int(x) for x in sys.argv[1:]]
byid = {i["id"]: (i, "open-array") for i in d["incidents"]}
byid.update({i["id"]: (i, "closed-array") for i in d["closed"]})
for n in ids:
    e, where = byid.get(n, (None, "MISSING"))
    print(f"########## #{n} ({where})")
    if not e:
        continue
    for k in ("title", "status", "severity", "affected", "linked", "observation", "expected", "suggestedResolution", "correctiveAction", "updated"):
        v = e.get(k)
        if isinstance(v, str) and len(v) > 1500:
            v = v[:1500] + "...[trunc]"
        print(f"  {k}: {v}")
