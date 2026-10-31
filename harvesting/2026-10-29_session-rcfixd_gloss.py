#!/usr/bin/env python3
"""gloss.py JSONFILE TERM... -- print glossary entries whose term matches (case-insensitive); report absent terms."""
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
print("top-level:", list(d.keys()))
entries = []
for k, v in d.items():
    if isinstance(v, list):
        for e in v:
            if isinstance(e, dict):
                entries.append((k, e))
    elif isinstance(v, dict) and k != "meta":
        for name, e in v.items():
            if isinstance(e, dict):
                e = dict(e)
                e.setdefault("term", name)
                entries.append((k, e))
print("entries:", len(entries), "sample keys:", list(entries[0][1].keys()) if entries else None)
for t in sys.argv[2:]:
    hits = [(k, e) for k, e in entries if str(e.get("term", "")).lower() == t.lower()]
    if not hits:
        print("ABSENT:", t)
    for k, e in hits:
        print("==", k, json.dumps(e, ensure_ascii=False))
