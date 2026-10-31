#!/usr/bin/env python3
"""List tool-registry invocation commands vs claude-shared.md Managed CLI Tools table (read-only)."""
import json
import re
from pathlib import Path

t = json.loads(Path("/Users/new-jose/repos/aitools/registries/tool-registry.json").read_text(encoding="utf-8"))["tools"]
table = Path("/Users/new-jose/repos/aitools/shared/claude-shared.md").read_text(encoding="utf-8")
cmds_in_table = set(re.findall(r"^\|[^|]+\|\s*`([^`]+)`", table, re.M))
for k, v in t.items():
    inv = ((v.get("lifecycle") or {}).get("invocation") or {})
    c = inv.get("command")
    st = (v.get("lifecycle") or {}).get("platformStatus")
    print(f"{k:18} cmd={c!r:28} inTable={c in cmds_in_table} status={st}")
