#!/usr/bin/env python3
"""Extract full content of L1096 and L1101."""

import json
from pathlib import Path

TRANSCRIPT = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl")

TARGET = [1096, 1101]

def deep_extract(content, depth=0):
    prefix = "  " * depth
    if isinstance(content, str):
        return prefix + content
    if isinstance(content, list):
        parts = []
        for block in content:
            parts.append(deep_extract(block, depth))
        return "\n".join(parts)
    if isinstance(content, dict):
        btype = content.get("type", "unknown")
        if btype == "text":
            return prefix + content.get("text", "")
        elif btype == "tool_result":
            inner = content.get("content", "")
            return prefix + f"[tool_result]:\n{deep_extract(inner, depth+1)}"
        elif btype == "tool_use":
            return prefix + f"[tool_use: {content.get('name', '')}({json.dumps(content.get('input', {}))[:200]})]"
        else:
            return prefix + f"[{btype}]: {json.dumps(content)[:500]}"
    return prefix + str(content)

with open(TRANSCRIPT) as f:
    for line_num, line in enumerate(f, 1):
        if line_num not in TARGET:
            continue
        line = line.strip()
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        message = entry.get("message", {})
        content = message.get("content", "")
        print(f"=== L{line_num} ===")
        print(deep_extract(content))
        print()
