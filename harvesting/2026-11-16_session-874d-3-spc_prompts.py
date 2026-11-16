#!/usr/bin/env python3
"""Print the commander's prompts at the given transcript lines (1-based) to prompts.txt."""
import json, pathlib
T = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d.jsonl"
LINES = [79, 289, 565, 907, 1275, 1665, 1921, 2160, 2442, 2553]
out = []
with open(T, encoding="utf-8") as f:
    for i, line in enumerate(f, 1):
        if i in LINES:
            j = json.loads(line)
            c = j.get("message", {}).get("content")
            if isinstance(c, list):
                c = "\n".join(p.get("text", "") for p in c if isinstance(p, dict) and p.get("type") == "text")
            out.append(f"===== L{i} {j.get('timestamp')} type={j.get('type')}\n{c}\n")
p = pathlib.Path(__file__).parent / "data" / "prompts.txt"
p.write_text("\n".join(out), encoding="utf-8")
print(len(out), "prompts written to", p)
