#!/usr/bin/env python3
"""Parse incidents.json at git refs; report ids, dups, max, and dump per-ref json."""
import json, subprocess, sys, collections

REPO = "/Users/new-jose/repos/aitools"
OUT = "/Users/new-jose/repos/aitools/.scratch/session-rcledg"

def load(ref: str) -> dict:
    raw = subprocess.run(["git", "-C", REPO, "show", f"{ref}:registries/incidents.json"],
                         check=True, capture_output=True, text=True).stdout
    return json.loads(raw)

for ref in sys.argv[1:]:
    d = load(ref)
    safe = ref.replace("/", "_")
    with open(f"{OUT}/inc-{safe}.json", "w") as f:
        json.dump(d, f, indent=1)
    open_ids = [i["id"] for i in d["incidents"]]
    closed_ids = [i["id"] for i in d["closed"]]
    allids = open_ids + closed_ids
    dups = [k for k, v in collections.Counter(allids).items() if v > 1]
    print(f"== {ref}: meta={d.get('meta', {}).get('lastUpdated')} open={len(open_ids)} closed={len(closed_ids)}")
    print(f"   max open={max(open_ids)} max closed={max(closed_ids)} max all={max(allids)} dups={dups}")
    missing = sorted(set(range(1, max(allids) + 1)) - set(allids))
    print(f"   gaps={missing}")
    print(f"   open ids>=140: {sorted(i for i in open_ids if i >= 140)}")
