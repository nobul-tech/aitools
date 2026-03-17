#!/usr/bin/env python3
"""Extract remaining key messages."""

import json
from pathlib import Path

TRANSCRIPT = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl")
OUTPUT_DIR = Path("/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/messages")

TARGET_LINES = [1111, 1115, 1117, 1122, 1124, 1129, 1131, 1135, 1137, 1194, 1229, 1254, 1259, 1283, 1307]

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
        if line_num not in TARGET_LINES:
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
        text = extract_text_content(message.get("content", ""))
        outfile = OUTPUT_DIR / f"L{line_num:04d}_{msg_type}.txt"
        with open(outfile, "w") as out:
            out.write(f"=== Line {line_num} | Type: {msg_type} ===\n\n")
            out.write(text)
        print(f"L{line_num:4d} [{msg_type:9s}] {len(text):6d} chars")
