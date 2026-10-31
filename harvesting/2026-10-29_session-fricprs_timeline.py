#!/usr/bin/env python3
"""Print commit + review timeline for given PRs, with first 1500 chars of each review/comment."""
import json, sys
d = "/Users/new-jose/repos/aitools/.scratch/session-fricprs/data"
for n in sys.argv[1:]:
    p = json.load(open(f"{d}/pr-{n}.json"))
    ev = []
    for c in p.get("commits") or []:
        ev.append((c.get("committedDate"), "commit", c["oid"][:7] + " " + c.get("messageHeadline", "")))
    for c in p.get("comments") or []:
        ev.append((c.get("createdAt"), "comment", c.get("body") or ""))
    for r in p.get("reviews") or []:
        ev.append((r.get("submittedAt"), "review", r.get("body") or ""))
    ev.append((p.get("mergedAt") or "9999", "MERGED", ""))
    ev.sort(key=lambda e: e[0] or "")
    print("#" * 30, n, p["title"])
    for t, k, b in ev:
        lim = 1500 if k != "commit" else 200
        print(f"[{t}] {k}: {b[:lim]}")
        print("-")
