#!/usr/bin/env python3
"""Show how the four verifier briefs differ from one another, node by node."""
import json

SCR = "/Users/new-jose/repos/aitools/.scratch/session-dbd05b0c-2365-4159-9976-bc64a2af874d/"
names = ["874d-3-spec-verify", "874d-4-adversarial", "874d-5-brief-verify", "874d-6-standards-verify"]
docs = {n: json.load(open(SCR + n + "-brief.json", encoding="utf-8")) for n in names}
base = docs[names[0]]
for k in base:
    vals = {n: json.dumps(docs[n][k], sort_keys=True) for n in names}
    same = len(set(vals.values())) == 1
    print("%-22s %s" % (k, "identical" if same else "differs"))
for n in names:
    d = docs[n]
    print("-" * 60)
    print(n)
    print(" intent.purpose:", d["intent"]["purpose"])
    print(" intent.scope:", d["intent"]["scope"])
    print(" OBJ-2:", d["objectives"][1]["text"][:300])
    print(" rules count:", len(d["rules"]), "has the implementing brief:",
          any("874d-2-structured-reports-brief" in r for r in d["rules"]))
    print(" duties:", d["duties"])
    print(" provenance.created_at:", d["provenance"]["created_at"])
