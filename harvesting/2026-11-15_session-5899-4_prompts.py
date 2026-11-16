#!/usr/bin/env python3
"""Extract the commander's typed prompts (not tool results) from the session JSONL."""
import json
import sys

path = sys.argv[1]
out = sys.argv[2]
n = 0
with open(path, encoding="utf-8") as f, open(out, "w", encoding="utf-8") as o:
    for line in f:
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") != "user":
            continue
        if d.get("isSidechain"):
            continue
        msg = d.get("message", {})
        c = msg.get("content")
        texts = []
        if isinstance(c, str):
            texts.append(c)
        elif isinstance(c, list):
            for b in c:
                if isinstance(b, dict) and b.get("type") == "text":
                    texts.append(b.get("text", ""))
        for t in texts:
            if t.startswith("<system-reminder>") or "tool_use_id" in t:
                continue
            n += 1
            o.write("=== MSG %d ts=%s uuid=%s len=%d\n" % (n, d.get("timestamp"), d.get("uuid"), len(t)))
            o.write(t)
            o.write("\n=== END %d\n" % n)
print(n)
