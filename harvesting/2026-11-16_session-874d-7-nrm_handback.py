#!/usr/bin/env python3
"""handback.py -- write the hand-back AAR: the full AAR with observations and
proposals limited to the high-severity defects (DEV-3).
Usage: python3 handback.py <full aar> <out>
"""
import json
import sys
from pathlib import Path

a = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
hi = [o for o in a["observations"] if o["severity"] == "high"]
ids = {o["id"] for o in hi}
a["observations"] = hi
a["proposals"] = [p for p in a["proposals"] if p["observation_refs"][0] in ids]
for o in a["objectives"]:
    o["observation_refs"] = sorted(ids, key=lambda s: int(s.split("-")[1]))
body = json.dumps(a, ensure_ascii=False, separators=(",", ":"))
body = body.replace('},{"id"', '},\n{"id"').replace('":[{"id"', '":[\n{"id"')
Path(sys.argv[2]).write_text(body + "\n", encoding="utf-8")
assert "`" * 3 not in body
print(len(body), "bytes;", len(a["observations"]), "observations;", len(a["proposals"]), "proposals")
