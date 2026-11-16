"""Merge the proposals of the language reviewers' AARs by RFC line, for review.

Usage: merge-proposals.py <out review file> <aar.json>...
A proposal's `what` is 'line <n>: <old> -> <new>' (or 'lines <a>-<b>: ...'); several edits may be
joined with ' ; line <n>: '. Writes every proposal, grouped by first line, with severity, old and new
in full; prints the lines that two or more proposals touch, and proposals whose `what` did not parse.
"""
import json
import re
import sys
from collections import defaultdict

out = sys.argv[1]
by_line = defaultdict(list)
unparsed = []
for path in sys.argv[2:]:
    a = json.load(open(path, encoding="utf-8"))
    mission = a["provenance"]["mission"].split("-")[1]
    sev = {o["id"]: o.get("severity") for o in a.get("observations", [])}
    for p in a.get("proposals", []):
        what = p.get("what", "")
        m = re.match(r"^\s*lines? (\d+)(?:\s*-\s*(\d+))?\s*:\s*(.*)$", what, re.S)
        o = (p.get("observation_refs") or ["?"])[0]
        tag = f"{mission}/{p['id']} ({sev.get(o)})"
        if not m:
            unparsed.append((tag, what))
            continue
        by_line[int(m.group(1))].append((tag, m.group(1) + (f"-{m.group(2)}" if m.group(2) else ""), m.group(3)))

with open(out, "w", encoding="utf-8") as f:
    for line in sorted(by_line):
        for tag, span, body in by_line[line]:
            f.write(f"\n===== L{span} {tag}\n{body}\n")
    for tag, what in unparsed:
        f.write(f"\n===== UNPARSED {tag}\n{what}\n")
print("lines touched:", len(by_line), "| proposals:", sum(len(v) for v in by_line.values()), "| unparsed:", len(unparsed))
print("lines with 2+ proposals:", [(l, [t for t, _, _ in v]) for l, v in sorted(by_line.items()) if len(v) > 1])
print("unparsed:", [t for t, _ in unparsed])
