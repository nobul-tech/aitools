"""Print every proposal of the verifier AARs: id, text, what, affected.

Usage: aar-proposals.py <aar.json>...
"""
import json
import sys

for path in sys.argv[1:]:
    a = json.load(open(path, encoding="utf-8"))
    print(f"\n######## {a['provenance']['mission']} ########")
    for p in a.get("proposals", []):
        print(f"\n{p['id']} | {p.get('text','')}\n  WHAT: {p.get('what','')}\n  AFFECTED: {p.get('affected','')}\n  OBS: {p.get('observation_refs','')}")
