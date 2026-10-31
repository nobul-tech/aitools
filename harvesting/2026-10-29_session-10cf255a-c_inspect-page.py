"""Inspect the S3-GateFix review-page JSON: keys per kind, one sample per section."""
import collections
import json
import sys

P = ("/Users/new-jose/repos/aitools/.claude/worktrees/gatefix/.aitools/channel/handoffs/"
     "2026-10-21_10cf255a-c-missions/S3-GateFix/S3-GateFix-review-page.json")


def main() -> int:
    with open(P, encoding="utf-8") as f:
        d = json.load(f)
    print("meta keys:", list(d["meta"].keys()))
    print("meta:", json.dumps(d["meta"])[:600])
    keys = collections.defaultdict(collections.Counter)
    for it in d["items"]:
        keys[it["kind"]].update(it.keys())
    for k, c in keys.items():
        print(k, dict(c))
    seen = set()
    for it in d["items"]:
        if it["section"] in seen:
            continue
        seen.add(it["section"])
        print("----", it["section"], it["kind"])
        print(json.dumps(it, indent=1)[:900])
    print("total chars:", len(json.dumps(d)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
