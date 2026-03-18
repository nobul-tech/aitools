#!/usr/bin/env python3
"""Add component (15) to decision #51."""
import json
from pathlib import Path

brief_path = Path("plans/mission-command-briefing/planning-brief.json")
brief = json.loads(brief_path.read_text())

component_15 = (
    "(15) Systemic finding escalation: when Plan Writer review reveals a finding "
    "that crosses section boundaries, reveals a governance gap, or indicates a class "
    "of problem the harness does not govern, the write-review loop pauses. S3 classifies: "
    "point fix (revise the section) or systemic (invoke the harness improvement cycle "
    "per decision #54 \u2014 investigate, structural-first generalization, barrier analysis, "
    "worktree-isolated fix, independent re-audit). S3 decides whether to run inline or "
    "defer to a batch. This prevents the Plan Writer loop from becoming an ad-hoc "
    "rewrite engine for structural problems"
)

for d in brief["decisions"]:
    if d.get("id") == 51:
        d["components"].append(component_15)
        print(f"Added component (15) to #51. Now {len(d['components'])} components.")
        break

brief_path.write_text(json.dumps(brief, indent=2, ensure_ascii=False) + "\n")
