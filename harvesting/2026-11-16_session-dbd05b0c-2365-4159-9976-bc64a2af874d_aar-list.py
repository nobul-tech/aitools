"""List an AAR's observations compactly: id, severity, text (cut to N chars).

Usage: aar-list.py <aar.json> [N]
"""
import json
import sys

a = json.load(open(sys.argv[1], encoding="utf-8"))
n = int(sys.argv[2]) if len(sys.argv) > 2 else 160
counts = {}
for o in a.get("observations", []):
    counts[o.get("severity")] = counts.get(o.get("severity"), 0) + 1
    print(o["id"], o.get("severity"), "|", o["text"][:n].replace("\n", " "))
print("counts:", counts, "| proposals:", len(a.get("proposals", [])), "| rfis:", [r["id"] for r in a.get("rfis", [])])
