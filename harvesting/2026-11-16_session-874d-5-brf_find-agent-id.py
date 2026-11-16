#!/usr/bin/env python3
"""Find the agentId of a delegate by its mission name: parent transcript, then subagents/*.meta.json."""
import glob
import json
import re
import sys

name = sys.argv[1]
parent = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d"
hits = set()
with open(parent + ".jsonl", encoding="utf-8") as fh:
    for line in fh:
        if name in line and "agentId" in line:
            for m in re.finditer(r'agentId[\\"]*\s*[:=]\s*[\\"]*([0-9a-f]{6,})', line):
                hits.add(m.group(1))
print("transcript hits:", sorted(hits))
for meta in glob.glob(parent + "/subagents/*.meta.json"):
    try:
        d = json.load(open(meta, encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print("unreadable", meta, e)
        continue
    if name in json.dumps(d):
        print("meta:", meta)
