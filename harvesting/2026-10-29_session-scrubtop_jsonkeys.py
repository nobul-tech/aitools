#!/usr/bin/env python3
"""Print top-level keys, meta, and tool keys of aitools registries (read-only audit helper)."""
import json
import sys
from pathlib import Path

R = Path("/Users/new-jose/repos/aitools/registries")
for name in ("tool-registry.json", "tool-ops.json", "framework-registry.json", "glossary.json", "incidents.json"):
    d = json.loads((R / name).read_text(encoding="utf-8"))
    print(f"== {name}")
    print("  top:", list(d.keys()))
    meta = d.get("meta", {})
    print("  meta:", {k: meta[k] for k in meta if k in ("schemaVersion", "lastUpdated", "version", "governance", "skill")})
    for k in ("tools", "mcpServers", "frameworks"):
        if k in d and isinstance(d[k], dict):
            print(f"  {k}:", list(d[k].keys()))
            if name == "tool-registry.json" and k == "tools":
                first = next(iter(d[k].values()))
                print("  first tool sections:", list(first.keys()))
            if name == "tool-ops.json" and k == "tools":
                for tk, tv in d[k].items():
                    print(f"   {tk} sections:", list(tv.keys()))
    if name == "incidents.json":
        inc = d.get("incidents", [])
        ids = [i.get("id") for i in inc]
        closed = d.get("closed", [])
        print("  open count:", len(inc), "max id open:", max(ids) if ids else None, "closed count:", len(closed),
              "max closed id:", max((c.get("id", 0) for c in closed), default=None))
    if name == "glossary.json":
        for k in d:
            if isinstance(d[k], (list, dict)) and k != "meta":
                print(f"  {k} count:", len(d[k]))
    if name == "framework-registry.json":
        for k in d:
            if isinstance(d[k], (list, dict)) and k != "meta":
                print(f"  {k} count:", len(d[k]), (list(d[k].keys())[:40] if isinstance(d[k], dict) else [x.get('id') or x.get('name') for x in d[k]][:40]))
sys.exit(0)
