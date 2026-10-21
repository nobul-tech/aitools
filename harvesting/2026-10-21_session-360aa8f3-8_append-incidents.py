#!/usr/bin/env python3
"""Append approved incident drafts to registries/incidents.json (preserves key order)."""
import json
import sys
from typing import Any

REG = "/Users/new-jose/repos/aitools/registries/incidents.json"
DRAFT = "/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/incidents-draft-74-86.json"
TODAY = "2026-10-21"


def main() -> int:
    with open(REG, encoding="utf-8") as f:
        reg: dict[str, Any] = json.load(f)
    with open(DRAFT, encoding="utf-8") as f:
        drafts: list[dict[str, Any]] = json.load(f)
    existing = {i["id"] for i in reg["incidents"]} | {c["id"] for c in reg.get("closed", [])}
    clash = [d["id"] for d in drafts if d["id"] in existing]
    if clash:
        print("ERROR: ids already present: %s" % clash)
        return 1
    if min(d["id"] for d in drafts) != max(existing) + 1:
        print("ERROR: drafts do not start at next id %d" % (max(existing) + 1))
        return 1
    reg["incidents"].extend(drafts)
    reg["meta"]["lastUpdated"] = TODAY
    with open(REG, "w", encoding="utf-8") as f:
        json.dump(reg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    with open(REG, encoding="utf-8") as f:
        check = json.load(f)
    print("OK: %d open incidents, max id %d" % (len(check["incidents"]), max(i["id"] for i in check["incidents"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
