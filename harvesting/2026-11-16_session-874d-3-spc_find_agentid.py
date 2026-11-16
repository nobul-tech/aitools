#!/usr/bin/env python3
"""Find the agentId of a mission in the parent transcript (tool results naming the mission) and in subagents/*.meta.json."""
import json, pathlib, re, sys
name = sys.argv[1]
T = pathlib.Path("/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d.jsonl")
for i, line in enumerate(T.open(encoding="utf-8"), 1):
    if name in line and "agentId" in line:
        for m in re.finditer(r'agentId[\\"\s:=]+([0-9a-f]{8,})', line):
            print(f"transcript L{i}: {m.group(1)}")
sub = T.with_suffix("") / "subagents"
if sub.is_dir():
    for meta in sorted(sub.glob("*.meta.json")):
        try:
            j = json.loads(meta.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            print(f"unreadable {meta.name}: {e}")
            continue
        if name in json.dumps(j):
            print(f"meta {meta.name}: {j.get('description')}")
