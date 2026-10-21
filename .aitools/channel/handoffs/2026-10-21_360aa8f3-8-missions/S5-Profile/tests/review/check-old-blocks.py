#!/usr/bin/env python3
"""Check each `old` fenced block in the S5-Profile plan occurs exactly once in its target file."""
import re
import sys
from pathlib import Path

REPO = Path("/Users/new-jose/repos/aitools")
PLAN = REPO / ".scratch/session-360aa8f3-8/missions/S5-Profile/S5-Profile-plan.md"
CANDIDATES = [
    "scripts/profile-check.js", "scripts/setup-user-claude.sh", "scripts/setup-user-claude.ps1",
    "scripts/build-deploy.sh", "scripts/aitools", "scripts/aitools.ps1",
    "scripts/aitools-install.sh", "scripts/aitools-install.ps1",
]

lines = PLAN.read_text().splitlines()
blocks = []
i = 0
while i < len(lines):
    ln = lines[i]
    if re.match(r"^\s*(old\b.*:|.*\bold:)\s*$", ln) or re.match(r"^old \(", ln) or ln.strip().startswith("Footer -- old:"):
        # find next fence
        j = i + 1
        while j < len(lines) and not lines[j].lstrip().startswith("```"):
            j += 1
        if j >= len(lines):
            break
        k = j + 1
        body = []
        while k < len(lines) and not lines[k].lstrip().startswith("```"):
            body.append(lines[k])
            k += 1
        blocks.append((i + 1, ln.strip(), "\n".join(body)))
        i = k + 1
        continue
    i += 1

texts = {c: (REPO / c).read_text() for c in CANDIDATES}
for lineno, label, body in blocks:
    hits = {c: t.count(body) for c, t in texts.items() if t.count(body)}
    status = "OK" if sum(hits.values()) == 1 else "PROBLEM"
    print(f"plan:{lineno} [{status}] {label[:60]!r} -> {hits or 'NOT FOUND'}")
    if status != "OK":
        # find first line that fails, per line
        for c, t in texts.items():
            pass
        first = body.splitlines()[0] if body else ""
        for c, t in texts.items():
            if first and first in t:
                print(f"    first line found in {c} x{t.count(first)}")
