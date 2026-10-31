"""Verify incidents #146-#171 on origin/main against the PR #102 batch (9861ff7)."""
import json
import subprocess
import sys

REPO = "/Users/new-jose/repos/aitools"
BATCH = ".aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-batch.json"


def show(ref: str, path: str) -> str:
    r = subprocess.run(["git", "-C", REPO, "show", f"{ref}:{path}"], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"git show {ref}:{path} failed: {r.stderr}")
    return r.stdout


def summarize(label: str, reg: dict) -> list:
    inc = reg.get("incidents", [])
    closed = reg.get("closed", [])
    ids = [e["id"] for e in inc] + [e["id"] for e in closed]
    dup = sorted({i for i in ids if ids.count(i) > 1})
    gaps = sorted(set(range(1, max(ids) + 1)) - set(ids))
    print(f"{label}: incidents={len(inc)} closed={len(closed)} max={max(ids)} dup={dup} gaps={gaps} lastUpdated={reg.get('meta', {}).get('lastUpdated')}")
    return inc


before = summarize("cc83abf", json.loads(show("cc83abf", "registries/incidents.json")))
after_raw = show("origin/main", "registries/incidents.json")
after = summarize("origin/main", json.loads(after_raw))
merge = show("742847c", "registries/incidents.json")
print("origin/main registry identical to 742847c:", merge == after_raw)

batch_doc = json.loads(show("9861ff7", BATCH))
batch = batch_doc if isinstance(batch_doc, list) else batch_doc.get("incidents", batch_doc.get("entries", []))
bids = [e["id"] for e in batch]
print("batch count", len(batch), "ids", min(bids), "-", max(bids), "contiguous", bids == list(range(min(bids), max(bids) + 1)))

amap = {e["id"]: e for e in after}
mism = [b["id"] for b in batch if amap.get(b["id"]) != b]
print("batch entries differing from registry:", mism)

bmap = {e["id"]: e for e in before}
changed = [i for i, e in bmap.items() if amap.get(i) != e]
print("pre-existing entries changed:", changed)

new = [e for e in after if e["id"] >= 146]
sev = {}
st = {}
for e in new:
    sev[e["severity"]] = sev.get(e["severity"], 0) + 1
    st[e["status"]] = st.get(e["status"], 0) + 1
print("new entries", len(new), "severity", sev, "status", st)

for ref in ("6686c16", "cc83abf", "origin/main"):
    d = json.loads(show(ref, BATCH))
    bl = d if isinstance(d, list) else d.get("incidents", d.get("entries", []))
    ids2 = [e["id"] for e in bl]
    diff = [e["id"] for e in bl if amap.get(e["id"]) != e]
    print(f"batch@{ref}: count={len(bl)} ids={min(ids2)}-{max(ids2)} differing_from_registry={diff}")
print("registry ids >=146 exactly batch ids:", sorted(e["id"] for e in new) == list(range(146, 172)))
