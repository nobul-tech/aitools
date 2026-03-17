#!/usr/bin/env python3
"""Find user messages in L1090-L1115 range to see what triggered execution protocol."""

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
        if line_num < 1090 or line_num > 1115:
            continue
        line = line.strip()
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg_type = entry.get("type")
        if msg_type not in ("user", "assistant"):
            continue
        message = entry.get("message", {})
        text = extract_text_content(message.get("content", ""))
        if text.strip():
            if msg_type == "user":
                print(f"L{line_num} [USER]: {text}")
            else:
                print(f"L{line_num} [AGENT]: {text[:400]}")
            print("---")
