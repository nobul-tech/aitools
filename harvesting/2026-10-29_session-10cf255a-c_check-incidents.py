"""Independent check of PR #65's registries/incidents.json: ids, counts, required keys."""
import json
import sys
from collections import Counter

P = "/Users/new-jose/repos/aitools/.claude/worktrees/incidents87/registries/incidents.json"
REQ = ["id", "title", "status", "severity", "affected", "linked", "referenceFile",
       "observation", "expected", "impact", "discoveryContext", "discipline",
       "frameworks", "suggestedResolution", "rootCause", "correctiveAction",
       "preventionLayer", "created", "updated"]


def main() -> int:
    with open(P, encoding="utf-8") as f:
        d = json.load(f)
    inc = d.get("incidents", [])
    closed = d.get("closed", [])
    ids = [e["id"] for e in inc + closed]
    print(f"incidents={len(inc)} closed={len(closed)} max={max(ids)} unique={len(set(ids)) == len(ids)}")
    print(f"contiguous 1..max: {sorted(ids) == list(range(1, max(ids) + 1))}")
    new = [e for e in inc + closed if e["id"] >= 87]
    print("severity of #87+:", dict(Counter(e.get("severity") for e in new)))
    missing = [(e["id"], k) for e in new for k in REQ if k not in e]
    print("missing required keys in #87+:", missing[:10], "count", len(missing))
    for i in (129, 134, 144):
        e = next(x for x in inc + closed if x["id"] == i)
        print(f"#{i} [{e['severity']}/{e['status']}] {e['title'][:110]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
