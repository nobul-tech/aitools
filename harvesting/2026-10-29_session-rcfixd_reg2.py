#!/usr/bin/env python3
"""reg2.py JSONFILE -- print the shapes of the rarely used tool-registry fields."""
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
for slug, t in d["tools"].items():
    v = t.get("versions", {})
    if "notes" in v or "maintenanceFile" in v:
        print(slug, "versions.notes:", type(v.get("notes")).__name__, repr(v.get("notes"))[:120])
        print(slug, "versions.maintenanceFile:", repr(v.get("maintenanceFile")))
    if "maintenance" in t:
        m = t["maintenance"]
        print(slug, "maintenance keys/types:", {k: type(x).__name__ for k, x in m.items()})
        w = m.get("workarounds")
        if isinstance(w, list) and w:
            print(slug, "workarounds[0] keys:", list(w[0].keys()))
        u = m.get("upstreamRisks")
        if isinstance(u, list) and u:
            print(slug, "upstreamRisks[0]:", list(u[0].keys()) if isinstance(u[0], dict) else type(u[0]).__name__)
        print(slug, "harness:", repr(m.get("harness"))[:160])
    dep = t.get("install", {}).get("deprecated")
    if dep:
        print(slug, "install.deprecated[0] keys:", list(dep[0].keys()))
    if "all" in t.get("install", {}):
        print(slug, "install.all keys:", list(t["install"]["all"].keys()) if isinstance(t["install"]["all"], dict) else t["install"]["all"])
first = next(iter(d["tools"].values()))
print("versions.macos keys:", list(first["versions"]["macos"].keys()) if isinstance(first["versions"]["macos"], dict) else first["versions"]["macos"])
print("versions.minVersion/blocked:", repr(first["versions"]["minVersion"]), repr(first["versions"]["blocked"]))
for k in ("configBehavior", "perlioDeployment", "setupScript"):
    for slug, t in d["tools"].items():
        if k in t:
            print(k, "in", slug, type(t[k]).__name__)
