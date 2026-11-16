"""Print glossary definitions for a few terms (read-only)."""
from __future__ import annotations

import json

with open("/Users/new-jose/repos/aitools/registries/glossary.json", encoding="utf-8") as f:
    g = json.load(f)
terms = g.get("terms", {})
for t in ("assumption", "observation", "deviation", "running estimate", "finding", "mission brief",
          "after action review", "blocker"):
    e = terms.get(t)
    print(f"== {t} ==")
    print(json.dumps(e, indent=1, ensure_ascii=False) if e else "(not found)")
