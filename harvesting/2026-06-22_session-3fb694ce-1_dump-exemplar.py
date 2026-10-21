#!/usr/bin/env python3
"""Dump full delegation prompts from c0dc2ddc by index."""
import json

path = "/Users/new-jose/repos/aitools-nobul-jose/sessions/aitools/2026-03-24_c0dc2ddc.jsonl"
want_idx = {0, 5}  # S2-Investigator and S3-Consolidator
prompts = []
with open(path) as fh:
    for line in fh:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg = obj.get("message", obj)
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for b in content:
            if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") in ("Agent", "Task"):
                p = (b.get("input") or {}).get("prompt", "")
                if "Mission" in p:
                    prompts.append(p)

for i in sorted(want_idx):
    if i < len(prompts):
        print(f"\n{'='*70}\nFULL EXEMPLAR PROMPT [{i}]  ({len(prompts[i])} chars)\n{'='*70}")
        print(prompts[i])
