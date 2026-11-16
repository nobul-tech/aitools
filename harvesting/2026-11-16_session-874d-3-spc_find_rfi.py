#!/usr/bin/env python3
"""Print text around a pattern in assistant messages of the transcript, before a given line.

Usage: find_rfi.py <pattern> <max_line>
"""
import json, sys
T = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d.jsonl"
pat, maxl = sys.argv[1], int(sys.argv[2])
with open(T, encoding="utf-8") as f:
    for i, line in enumerate(f, 1):
        if i >= maxl:
            break
        if pat not in line:
            continue
        j = json.loads(line)
        if j.get("type") != "assistant":
            continue
        for p in j.get("message", {}).get("content", []):
            if isinstance(p, dict) and p.get("type") == "text" and pat in p["text"]:
                t = p["text"]
                k = t.find(pat)
                print(f"--- L{i}\n{t[max(0, k-200):k+900]}\n")
