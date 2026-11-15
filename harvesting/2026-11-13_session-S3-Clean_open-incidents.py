#!/usr/bin/env python3
"""List open incidents (read-only) whose text cites a deleted or moved artifact."""
import json
import re

path = "/Users/new-jose/repos/aitools/registries/incidents.json"
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
pat = re.compile(r"sources-of-truth|/audit\b|skills/audit|relay-outbound|artifact-harvesting|shared/skills/(frameworks|glossary|incident)")
print("open incidents:", len(data["incidents"]), "closed:", len(data["closed"]))
for inc in data["incidents"]:
    text = json.dumps(inc)
    hits = sorted(set(m.group(0) for m in pat.finditer(text)))
    if hits:
        print(f"#{inc['id']} [{inc.get('status')}/{inc.get('severity')}] {inc['title'][:110]} -> {', '.join(hits)}")
