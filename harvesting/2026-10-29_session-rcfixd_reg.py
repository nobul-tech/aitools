#!/usr/bin/env python3
"""reg.py JSONFILE -- report top-level keys, per-tool section keys, and nested field names used across tools."""
import json
import sys
from collections import Counter

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
print("top-level:", list(d.keys()))
tools = d.get("tools", {})
sec = Counter()
per = {}
for slug, t in tools.items():
    for k, v in t.items():
        sec[k] += 1
        if isinstance(v, dict):
            per.setdefault(k, Counter()).update(v.keys())
print("tools:", len(tools))
print("sections:", dict(sec))
for k in ("maintenance", "versions", "install"):
    print(k, "subkeys:", dict(per.get(k, {})))
dep_note = 0
ver_notes = 0
for slug, t in tools.items():
    for dep in (t.get("install", {}) or {}).get("deprecated", []) or []:
        if isinstance(dep, dict) and "notes" in dep:
            dep_note += 1
    v = t.get("versions", {}) or {}
    if "notes" in v or "maintenanceFile" in v:
        ver_notes += 1
print("install.deprecated[].notes count:", dep_note)
print("tools with versions.notes/maintenanceFile:", ver_notes)
print("top-level overrides type:", type(d.get("overrides")).__name__, "keys:", list((d.get("overrides") or {}).keys())[:10] if isinstance(d.get("overrides"), dict) else d.get("overrides"))
