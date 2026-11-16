"""Print chosen decision items of a brief, and every item with an empty quote.

Usage: brief-sample.py <brief.json> <id>...
"""
import json
import sys

b = json.load(open(sys.argv[1], encoding="utf-8"))
want = set(sys.argv[2:])
for d in b["decisions"]:
    if d["id"] in want or not d.get("quote"):
        print(d["id"], "|", d["source"]["kind"], "|", d["source"]["location"][:150])
        print("   quote:", repr(d.get("quote", "")[:110]), "| superseded_by:", d.get("superseded_by"))
print("deliverables:", json.dumps(b["deliverables"][0]), "...", json.dumps(b["deliverables"][-1]))
