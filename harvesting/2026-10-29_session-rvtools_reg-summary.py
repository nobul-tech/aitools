#!/usr/bin/env python3
"""Summarize tool-registry install methods, status, and scope mentions (read-only)."""
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    reg = json.load(f)

for slug, t in reg.get("tools", {}).items():
    print("=" * 70)
    print("TOOL:", slug, "|", t.get("displayName"))
    lc = t.get("lifecycle", {})
    print("  platformStatus:", json.dumps(lc.get("platformStatus")))
    if lc.get("environments"):
        print("  environments:", json.dumps(lc.get("environments")))
    print("  setupScript:", lc.get("setupScript"))
    inst = t.get("install", {})
    for plat, v in inst.items():
        print("  install.%s: %s" % (plat, json.dumps(v)[:900]))
    if t.get("knownPaths"):
        print("  knownPaths:", json.dumps(t.get("knownPaths"))[:400])
    blob = json.dumps(t).lower()
    for kw in ["--scope", "machine", "admin", "elevat", "sudo", "root", "system"]:
        if kw in blob:
            idx = blob.find(kw)
            print("  [kw %s] ...%s..." % (kw, blob[max(0, idx - 120): idx + 120]))
