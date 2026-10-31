#!/usr/bin/env python3
"""Filter markers.tsv to real INCIDENT markers in the in-scope sources.
usage: filter.py [folder-substring ...]  (prints matching lines)"""
import re, sys
EXCL_FOLDERS = ("S3-BuildPkg", "S3-FanPlan", "S3-Reconcile", "SC-mission-packet", "S3-M3-", "S3-Profile", "S3-MF-Incidents")
MARK = re.compile(r"INCIDENT(\s*\(|\s*:|\*\*\s*:|:\*\*|\b\s*[-—–]\s)")
NOISE = re.compile(r"INCIDENT:?`?\s*(markers?|lines?|findings?)\b|`INCIDENT:`|INCIDENT: <|INCIDENT:\s*none|INCIDENT markers", re.I)
want = sys.argv[1:]
rows = []
for line in open("/Users/new-jose/repos/aitools/.scratch/session-rcledg/markers.tsv", encoding="utf-8"):
    ref, loc, text = line.rstrip("\n").split("\t", 2)
    folder = loc.split("/")[4] if loc.count("/") >= 4 else loc
    if any(folder.startswith(e) for e in EXCL_FOLDERS):
        continue
    if want and not any(w in folder for w in want):
        continue
    if not MARK.search(text) or (NOISE.search(text) and not re.search(r"INCIDENT\s*(\(|:)\s*[A-Za-z`]", NOISE.sub("", text))):
        continue
    rows.append((folder, ref, loc, text))
for r in rows:
    print("\t".join(r[1:]))
print(f"# {len(rows)} markers", file=sys.stderr)
