#!/usr/bin/env python3
"""Print the last N main-chain assistant text blocks before a given user uuid.
usage: before.py JSONL UUID [N]"""
import json, sys
path, target = sys.argv[1], sys.argv[2]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 1
texts = []
with open(path, encoding="utf-8") as f:
    for line in f:
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("uuid") == target:
            break
        if d.get("isSidechain") or d.get("type") != "assistant":
            continue
        c = d.get("message", {}).get("content")
        if isinstance(c, list):
            t = "\n".join(b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text")
            if t.strip():
                texts.append((d.get("timestamp"), d.get("uuid"), t))
for ts, u, t in texts[-n:]:
    print(f"=== {ts} {u}")
    print(t)
