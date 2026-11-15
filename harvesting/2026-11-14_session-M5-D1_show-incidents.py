"""Print incidents by id from registries/incidents.json (both arrays), plus max id and meta."""
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
ids = {int(x) for x in sys.argv[2:]}
d = json.loads((root / "registries" / "incidents.json").read_text(encoding="utf-8"))
print("meta:", json.dumps(d.get("meta"), indent=2))
print("max id:", max(i["id"] for i in d["incidents"] + d["closed"]))
print("open count:", len(d["incidents"]), "closed count:", len(d["closed"]))
for arr in ("incidents", "closed"):
    for i in d[arr]:
        if i["id"] in ids:
            print(f"--- [{arr}] ---")
            print(json.dumps(i, indent=2, ensure_ascii=False))
print("--- last closed entry (format sample) ---")
print(json.dumps(d["closed"][-1], indent=2, ensure_ascii=False))
