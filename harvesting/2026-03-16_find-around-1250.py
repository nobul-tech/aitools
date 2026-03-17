#!/usr/bin/env python3
"""Find all messages in L1240-L1270 range."""

import json
from pathlib import Path

TRANSCRIPT = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl")

def extract_text_content(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                texts.append(block.get("text", ""))
            elif isinstance(block, str):
                texts.append(block)
        return "\n".join(texts)
    return str(content)

with open(TRANSCRIPT) as f:
    for line_num, line in enumerate(f, 1):
        if line_num < 1242 or line_num > 1275:
            continue
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg_type = entry.get("type")
        message = entry.get("message", {})
        role = message.get("role", "")
        text = extract_text_content(message.get("content", ""))
        if text.strip():
            if msg_type == "user":
                print(f"L{line_num} [USER]: {text}")
            else:
                print(f"L{line_num} [{msg_type}]: {text[:300]}...")
            print("---")
        elif msg_type in ("user", "assistant"):
            print(f"L{line_num} [{msg_type}]: (empty)")
            print("---")
