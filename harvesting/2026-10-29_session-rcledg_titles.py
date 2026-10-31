#!/usr/bin/env python3
"""Print id, status, severity, title for all incidents (main) + PR 102 batch.
Optional args: regexes; then print only entries whose full JSON text matches any (case-insensitive)."""
import json, re, sys
d = json.load(open("/Users/new-jose/repos/aitools/.scratch/session-rcledg/inc-origin_main.json"))
b = json.load(open("/Users/new-jose/repos/aitools/.scratch/session-rcledg/batch102.json"))
rows = [(i, "open") for i in d["incidents"]] + [(i, "CLOSED") for i in d["closed"]] + [(i, "draft102") for i in b]
rx = [re.compile(a, re.I) for a in sys.argv[1:]]
for e, where in sorted(rows, key=lambda r: r[0]["id"]):
    if rx:
        t = json.dumps(e)
        hits = [r.pattern for r in rx if r.search(t)]
        if not hits:
            continue
        print(f"#{e['id']} [{where}/{e.get('status','')}/{e.get('severity','')}] {e['title'][:230]}  <= {hits}")
    else:
        print(f"#{e['id']} [{where}/{e.get('severity','')}] {e['title'][:200]}")
