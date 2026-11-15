#!/usr/bin/env python3
"""Check that every framework-registry artifact and referenceFile path exists (read-only)."""
import json
import os
import re
import sys

root = "/Users/new-jose/repos/aitools"
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "registries/framework-registry.json")
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
for kind in ("frameworks", "pending"):
    for fw in data[kind]:
        items = [("referenceFile", fw.get("referenceFile"))] + [("artifact", a) for a in fw.get("artifacts", [])]
        for label, item in items:
            if not item:
                continue
            p = re.split(r" \(", item)[0].strip()
            if "*" in p:
                continue
            ok = os.path.exists(os.path.join(root, p))
            print(f"{'OK  ' if ok else 'MISS'} {kind}:{fw['name']}: {label}: {item}")
