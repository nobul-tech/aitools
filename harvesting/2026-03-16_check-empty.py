#!/usr/bin/env python3
"""Check what's in the 'empty' user messages."""

import json
from pathlib import Path

TRANSCRIPT = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl")

TARGET = [1244, 1249, 1253, 1258, 1263, 1266]

with open(TRANSCRIPT) as f:
    for line_num, line in enumerate(f, 1):
        if line_num not in TARGET:
            continue
        line = line.strip()
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = entry.get("type")
        message = entry.get("message", {})
        content = message.get("content", "")

        # Show raw content structure
        if isinstance(content, list):
            for i, block in enumerate(content):
                if isinstance(block, dict):
                    btype = block.get("type", "unknown")
                    if btype == "tool_result":
                        print(f"L{line_num} [{msg_type}]: tool_result block {i}")
                        # Show tool result content
                        tr_content = block.get("content", "")
                        if isinstance(tr_content, list):
                            for trc in tr_content:
                                if isinstance(trc, dict):
                                    print(f"  sub-block type: {trc.get('type')}, text: {str(trc.get('text', ''))[:100]}")
                        elif isinstance(tr_content, str):
                            print(f"  content: {tr_content[:100]}")
                    else:
                        text = block.get("text", "")
                        print(f"L{line_num} [{msg_type}]: {btype} block {i}: {text[:200]}")
                else:
                    print(f"L{line_num} [{msg_type}]: str block {i}: {str(block)[:200]}")
        elif isinstance(content, str):
            print(f"L{line_num} [{msg_type}]: string: {content[:200]}")
        print("---")
