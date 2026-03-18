#!/usr/bin/env python3
"""Fix readingOrder in planning brief to include all 53 active decisions."""
import json
from pathlib import Path

brief_path = Path("plans/mission-command-briefing/planning-brief.json")
brief = json.loads(brief_path.read_text())

new_reading_order = {
    "description": "Recommended consumption sequence for the executing agent. IDs are stable — this reorders without renumbering. /brief skill presents decisions in this order.",
    "sequence": [
        {
            "phase": "1. Critical blockers — resolve before anything",
            "items": ["F1", "F2", "F3", "F17"]
        },
        {
            "phase": "2. All facts — verified ground truth",
            "items": ["F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15", "F16", "F18"]
        },
        {
            "phase": "3. All assumptions — accepted for planning, unverified",
            "items": ["A1", "A2", "A3", "A4", "A5", "A6", "A7"]
        },
        {
            "phase": "4. Framework definitions — build mental model before reading decisions",
            "items": [3, 8, 13, 36, 37, 38]
        },
        {
            "phase": "5. Critical blocker resolution decisions",
            "items": [29, 39, 40, 41]
        },
        {
            "phase": "6. Mission Command decisions",
            "items": [4, 5, 6, 7, 15, 16, 49, 17, 19, 20, 22, 23, 24, 25, 26, 27, 28, 44]
        },
        {
            "phase": "7. Platform Engineering decisions",
            "items": [9]
        },
        {
            "phase": "8. Mission Analysis decisions",
            "items": [21, 43, 45]
        },
        {
            "phase": "9. Operational Learning decisions",
            "items": [1, 2, 10, 11, 12, 14, 18, 30, 46, 47]
        },
        {
            "phase": "10. Infrastructure decisions",
            "items": [32, 33, 34, 50, 42, 53]
        },
        {
            "phase": "11. Process decisions",
            "items": [35, 48, 54]
        },
        {
            "phase": "12. Plan-writing protocol",
            "items": [51, 52]
        }
    ]
}

brief["meta"]["readingOrder"] = new_reading_order

# Verify all active decision IDs are covered
all_ids = set()
for phase in new_reading_order["sequence"]:
    for item in phase["items"]:
        if isinstance(item, int):
            all_ids.add(item)

decision_ids = set()
for d in brief["decisions"]:
    did = d.get("id")
    if did and d.get("status") != "merged":
        decision_ids.add(did)

missing = decision_ids - all_ids
extra = all_ids - decision_ids

brief_path.write_text(json.dumps(brief, indent=2, ensure_ascii=False) + "\n")

print(f"Updated readingOrder: {len(all_ids)} decision IDs across {len(new_reading_order['sequence'])} phases")
if missing:
    print(f"WARNING — decisions missing from readingOrder: {sorted(missing)}")
if extra:
    print(f"WARNING — IDs in readingOrder but not in decisions: {sorted(extra)}")
if not missing and not extra:
    print("All active decisions covered. No gaps.")
