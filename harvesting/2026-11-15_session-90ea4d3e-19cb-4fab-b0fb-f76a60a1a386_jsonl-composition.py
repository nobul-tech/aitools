#!/usr/bin/env python3
"""Measure composition of a Claude Code session JSONL: bytes by entry type and content block type."""
import json
import sys
from collections import Counter

path = sys.argv[1]
by_type: Counter[str] = Counter()
by_block: Counter[str] = Counter()
count_type: Counter[str] = Counter()
first_ts = last_ts = None
with open(path, encoding="utf-8") as f:
    for line in f:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            by_type["<bad-json>"] += len(line)
            continue
        t = obj.get("type", "?")
        by_type[t] += len(line)
        count_type[t] += 1
        ts = obj.get("timestamp")
        if ts:
            first_ts = first_ts or ts
            last_ts = ts
        msg = obj.get("message")
        if isinstance(msg, dict):
            c = msg.get("content")
            if isinstance(c, str):
                by_block[f"{t}:text(str)"] += len(c)
            elif isinstance(c, list):
                for b in c:
                    if isinstance(b, dict):
                        bt = b.get("type", "?")
                        by_block[f"{t}:{bt}"] += len(json.dumps(b.get("text") or b.get("thinking") or b.get("input") or b.get("content") or "", ensure_ascii=False))
print(f"span: {first_ts} -> {last_ts}")
print("== bytes by entry type ==")
for k, v in by_type.most_common():
    print(f"{k:30} {v:>10}  ({count_type[k]} entries)")
print("== chars by content block ==")
for k, v in by_block.most_common():
    print(f"{k:30} {v:>10}")
