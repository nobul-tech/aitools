#!/usr/bin/env python3
"""Print assistant text blocks containing a search term, with message index and timestamp."""
import json
import sys

path = sys.argv[1]
term = sys.argv[2]
out = sys.argv[3]
n = 0
with open(path, encoding="utf-8") as f, open(out, "w", encoding="utf-8") as o:
    for line in f:
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") != "assistant" or d.get("isSidechain"):
            continue
        c = d.get("message", {}).get("content")
        if not isinstance(c, list):
            continue
        for b in c:
            if isinstance(b, dict) and b.get("type") == "text":
                t = b.get("text", "")
                if term in t:
                    n += 1
                    o.write("=== A%d ts=%s len=%d\n" % (n, d.get("timestamp"), len(t)))
                    o.write(t)
                    o.write("\n=== END\n")
print(n)
