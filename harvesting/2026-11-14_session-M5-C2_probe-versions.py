"""Read-only probe (via /tool-registry): how tools.<slug>.versions record
unverified and n/a platforms. Counts lastVerifiedVersion values per platform
and cross-tabulates them with lifecycle.platformStatus."""
import json
import sys
from collections import Counter

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

tools = data["tools"]
print(f"tools: {len(tools)}")
kinds: Counter = Counter()
pending_hits = []
cross: Counter = Counter()
shapes: Counter = Counter()
for key, t in tools.items():
    v = t.get("versions")
    if v is None:
        shapes["versions missing/null"] += 1
        continue
    shapes["keys: " + ",".join(sorted(v.keys()))] += 1
    status = ((t.get("lifecycle") or {}).get("platformStatus")) or {}
    for plat in ("macos", "windows", "linux"):
        pv = v.get(plat)
        if pv is None:
            val = "<platform key missing or null>"
            lv = None
        elif isinstance(pv, dict):
            lv = pv.get("lastVerifiedVersion", "<no lastVerifiedVersion key>")
            val = "null" if lv is None else ("pending" if lv == "pending" else ("str" if isinstance(lv, str) else type(lv).__name__))
        else:
            val = f"<non-object: {pv!r}>"
            lv = pv
        kinds[(plat, val)] += 1
        st = status.get(plat) if isinstance(status, dict) else None
        if isinstance(st, dict):
            st = st.get("status")
        cross[(str(st), val)] += 1
        if st is None:
            print(f"no platformStatus: {key}.{plat} versions={pv!r} platformStatus={status!r}")
        if lv == "pending" or (isinstance(pv, dict) and pv.get("lastVerified") == "pending"):
            pending_hits.append((key, plat, pv))
print("versions shapes:")
for k, n in sorted(shapes.items()):
    print(f"  {n:3d}  {k}")
print("per platform lastVerifiedVersion kinds:")
for (plat, val), n in sorted(kinds.items()):
    print(f"  {plat:8s} {val:35s} {n}")
print("platformStatus x version kind:")
for (st, val), n in sorted(cross.items()):
    print(f"  status={st:15s} version={val:35s} {n}")
print(f"'pending' hits: {len(pending_hits)}")
for h in pending_hits:
    print("  ", h)
# any "pending" string anywhere in versions
raw = json.dumps({k: t.get("versions") for k, t in tools.items()})
print("'pending' substring in any tools.*.versions:", "pending" in raw)
# n/a examples
print("n/a examples:")
shown = 0
for key, t in tools.items():
    status = ((t.get("lifecycle") or {}).get("platformStatus")) or {}
    for plat, st in (status.items() if isinstance(status, dict) else []):
        s = st.get("status") if isinstance(st, dict) else st
        if s == "n/a" and shown < 6:
            print(f"  {key}.{plat}: status={st!r} versions.{plat}={(t.get('versions') or {}).get(plat)!r}")
            shown += 1
