#!/usr/bin/env python3
"""Fix reciprocal related links for decision #54 in planning brief."""
import json
from pathlib import Path

brief_path = Path("plans/mission-command-briefing/planning-brief.json")
brief = json.loads(brief_path.read_text())

# Decisions that need 54 added to their related arrays
need_54 = [4, 35, 36, 41, 44, 45, 46, 48, 50, 51, 52, 53]

# Decision 54 needs 50, 51, 52 added
d54_add = [50, 51, 52]

changes = []

for d in brief["decisions"]:
    did = d.get("id")
    if did is None:
        continue

    related = d.get("related", [])

    # Add 54 to decisions that need it
    if did in need_54 and 54 not in related:
        related.append(54)
        related.sort()
        d["related"] = related
        changes.append(f"  #{did}: added 54")

    # Add 50, 51, 52 to decision 54
    if did == 54:
        for add_id in d54_add:
            if add_id not in related:
                related.append(add_id)
        related.sort()
        d["related"] = related
        changes.append(f"  #54: added {d54_add}")

brief_path.write_text(json.dumps(brief, indent=2, ensure_ascii=False) + "\n")

print(f"Updated {len(changes)} decisions:")
for c in changes:
    print(c)
