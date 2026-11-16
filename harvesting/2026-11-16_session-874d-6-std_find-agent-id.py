"""Find this delegate's agentId in the parent transcript and subagents dir (read-only)."""
import os
import re

base = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d"
parent = base + ".jsonl"
name = "874d-6"
pat = re.compile(r'"agentId"\s*:\s*"([0-9a-zA-Z_-]+)"')
with open(parent, encoding="utf-8") as f:
    for n, line in enumerate(f, 1):
        if name in line and "agentId" in line:
            for m in pat.finditer(line):
                print(f"L{n}: agentId {m.group(1)}")
sub = os.path.join(base, "subagents")
if os.path.isdir(sub):
    for fn in sorted(os.listdir(sub)):
        if fn.endswith(".meta.json"):
            with open(os.path.join(sub, fn), encoding="utf-8") as f:
                txt = f.read()
            if name in txt:
                print("meta:", fn, txt[:200])
        elif fn.endswith(".jsonl"):
            with open(os.path.join(sub, fn), encoding="utf-8") as f:
                first = f.readline()
            if "874d-6-standards-verify" in first:
                print("transcript:", fn)
