"""Summarize harvest-manifest.json and scratch state for the reference doc."""
import collections
import json
import pathlib

root = pathlib.Path("/Users/new-jose/repos/aitools")
m = json.loads((root / "harvesting/harvest-manifest.json").read_text())
arts = m.get("artifacts", {})
print("meta:", m.get("meta"))
print("artifacts:", len(arts))
print("status:", collections.Counter(a.get("status") for a in arts.values()))
print("type:", collections.Counter(a.get("type") for a in arts.values()))
dot = [k for k in arts if k.split("_", 2)[-1].startswith(".")]
print("dotfile entries:", len(dot), dot[:5])
print("events.jsonl entries:", sum(1 for k in arts if k.endswith("events.jsonl")))
keys = collections.Counter(tuple(sorted(a.keys())) for a in arts.values())
print("entry key sets:", keys.most_common(3))
cs = root / ".scratch/.current-session"
print(".current-session exists:", cs.exists(), cs.read_text() if cs.exists() else "")
sd = root / ".scratch"
dirs = [p for p in sd.iterdir() if p.is_dir() and p.name.startswith("session-")]
print("session dirs:", len(dirs), "with .harvested:", sum((p / ".harvested").exists() for p in dirs))
print("handoffs routed (date-prefixed):", [p.name for p in (root / ".aitools/channel/handoffs").iterdir() if p.name[:2] == "20" and "_session-" in p.name][:5])
