#!/usr/bin/env python3
"""Find ALL entries between L1094 and L1103."""

import json
from pathlib import Path

TRANSCRIPT = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl")

def extract_text_content(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, dict):
                btype = block.get("type", "unknown")
                if btype == "text":
                    texts.append(block.get("text", ""))
                elif btype == "tool_result":
                    tr = block.get("content", "")
                    if isinstance(tr, str):
                        texts.append(f"[tool_result: {tr[:200]}]")
                    elif isinstance(tr, list):
                        for sub in tr:
                            if isinstance(sub, dict) and sub.get("type") == "text":
                                texts.append(f"[tool_result: {sub.get('text', '')[:200]}]")
                elif btype == "tool_use":
                    texts.append(f"[tool_use: {block.get('name', 'unknown')}]")
            elif isinstance(block, str):
                texts.append(block)
        return "\n".join(texts)
    return str(content)

with open(TRANSCRIPT) as f:
    for line_num, line in enumerate(f, 1):
        if line_num < 1094 or line_num > 1103:
            continue
        line = line.strip()
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg_type = entry.get("type")
        message = entry.get("message", {})
        text = extract_text_content(message.get("content", ""))
        ts = entry.get("timestamp", "")
        print(f"L{line_num} [{msg_type}] {ts}: {text[:500]}")
        print("---")
