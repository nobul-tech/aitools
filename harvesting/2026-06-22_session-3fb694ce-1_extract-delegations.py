#!/usr/bin/env python3
"""Extract Agent/Task delegation prompts from a CC session JSONL."""
import json, sys

path = sys.argv[1]
want = sys.argv[2] if len(sys.argv) > 2 else None  # optional substring filter

out = []
with open(path) as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg = obj.get("message", obj)
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use" and block.get("name") in ("Agent", "Task"):
                inp = block.get("input", {}) or {}
                prompt = inp.get("prompt", "")
                stype = inp.get("subagent_type", inp.get("description", ""))
                if want and want.lower() not in prompt.lower():
                    continue
                out.append((stype, prompt))

print(f"== {len(out)} delegations in {path.split('/')[-1]} ==\n")
for i, (stype, prompt) in enumerate(out):
    print(f"--- [{i}] subagent_type={stype} | prompt_len={len(prompt)} chars ---")
    print(prompt[:1400])
    print()
