#!/usr/bin/env python3
"""Extract full content of specific lines from session transcript."""

import json
import sys
from pathlib import Path

TRANSCRIPT = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl")
OUTPUT_DIR = Path("/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/messages")

# Key lines to extract in full
TARGET_LINES = [
    # Early subagent/duty context
    722, 754, 770, 811, 834, 852, 861,
    # Execution protocol first proposed
    1103, 1108, 1112,
    # Delegation duty born
    1187, 1189,
    # Evolution
    1208, 1224, 1242,
    # Recursive/generalized
    1260, 1264,
    # Include the plan / FRAGORD
    1268,
    # Identity duty
    1271, 1278,
    # Final version
    1298, 1316,
    # Also grab nearby user messages for context
    1236, 1238, 1240, 1258, 1260, 1262, 1266, 1270,
]

# Remove duplicates and sort
TARGET_LINES = sorted(set(TARGET_LINES))

def extract_text_content(content):
    """Extract text from message content."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text":
                    texts.append(block.get("text", ""))
            elif isinstance(block, str):
                texts.append(block)
        return "\n".join(texts)
    return str(content)

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with open(TRANSCRIPT, "r") as f:
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

            msg_type = entry.get("type", "unknown")
            message = entry.get("message", {})
            role = message.get("role", "unknown")
            content = message.get("content", "")
            text = extract_text_content(content)

            outfile = OUTPUT_DIR / f"L{line_num:04d}_{msg_type}_{role}.txt"
            with open(outfile, "w") as out:
                out.write(f"=== Line {line_num} | Type: {msg_type} | Role: {role} ===\n\n")
                out.write(text)

            print(f"L{line_num:4d} [{msg_type:9s}/{role:9s}] {len(text):6d} chars -> {outfile.name}")

if __name__ == "__main__":
    main()
