"""Check registry JSON: parse, and list glossary 'source' paths that do not exist."""
import json
import os
import sys

root = "/Users/new-jose/repos/aitools"
files = ["registries/glossary.json", "registries/tool-ops.json", "registries/tool-registry.json"]
for f in files:
    with open(os.path.join(root, f), encoding="utf-8") as fh:
        json.load(fh)
    print(f"parse ok: {f}")

with open(os.path.join(root, "registries/glossary.json"), encoding="utf-8") as fh:
    g = json.load(fh)

missing = 0
for name, entry in g.get("terms", {}).items():
    src = entry.get("source") if isinstance(entry, dict) else None
    if not src:
        continue
    path = src.split("#")[0].split(" ")[0].strip()
    if path.startswith("http") or "/" not in path:
        continue
    if not os.path.exists(os.path.join(root, path)):
        missing += 1
        print(f"missing source: {name!r} -> {src}")
print(f"missing sources: {missing}")
sys.exit(0)
