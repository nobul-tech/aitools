"""Validate the framework registry: parses, required fields, new entries' paths exist."""
import json
import os
import sys

repo = sys.argv[1]
path = os.path.join(repo, "registries", "framework-registry.json")
with open(path, encoding="utf-8") as f:
    data = json.load(f)
required = ["name", "governs", "discipline", "concepts", "referenceFile", "artifacts", "lastUpdated"]
bad = 0
for fw in data["frameworks"]:
    missing = [k for k in required if k not in fw]
    if missing:
        print(f"MISSING {fw.get('name')}: {missing}")
        bad += 1
for name in ("Adversarial review", "Perspective-based reading"):
    fw = next((x for x in data["frameworks"] if x["name"] == name), None)
    if fw is None:
        print(f"NOT FOUND: {name}")
        bad += 1
        continue
    for p in [fw["referenceFile"]] + fw["artifacts"]:
        p = p.split(" (")[0]
        ok = os.path.exists(os.path.join(repo, p))
        print(f"{name}: {p} exists={ok}")
        bad += 0 if ok else 1
print(f"meta.lastUpdated={data['meta']['lastUpdated']} frameworks={len(data['frameworks'])} pending={len(data['pending'])}")
print("OK" if bad == 0 else f"FAIL ({bad})")
sys.exit(1 if bad else 0)
