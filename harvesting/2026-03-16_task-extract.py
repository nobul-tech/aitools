#!/usr/bin/env python3
"""Extract delegation protocol evolution from session transcript.

Purpose: Parse JSONL session transcript and extract messages containing
keywords related to execution protocol, delegation duty, identity concepts.
"""

import json
import sys
import re
from pathlib import Path

TRANSCRIPT = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_84280c8b.jsonl")
OUTPUT = Path("/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/extracted-messages.json")

KEYWORDS = [
    "execution protocol",
    "delegat",
    "identity",
    "briefing",
    "duty",
    "OPORD",
    "FRAGORD",
    "harness constraint",
    "recursive",
    "sub-agent",
    "subagent",
    "before delegating",
    "include the plan",
    "five constraints",
    "5 constraints",
    "agent identity",
    "who they are",
    "update.*instructions",
    "passing.*context",
    "continuation",
]

def extract_text_content(content):
    """Extract text from message content (can be string or list of blocks)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text":
                    texts.append(block.get("text", ""))
                elif block.get("type") == "tool_result":
                    # Skip tool results for now
                    pass
            elif isinstance(block, str):
                texts.append(block)
        return "\n".join(texts)
    return str(content)

def main():
    results = []

    with open(TRANSCRIPT, "r") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = entry.get("type")
            if msg_type not in ("user", "assistant"):
                continue

            message = entry.get("message", {})
            content = message.get("content", "")
            text = extract_text_content(content)

            # Check for keyword matches
            matched_keywords = []
            for kw in KEYWORDS:
                if re.search(kw, text, re.IGNORECASE):
                    matched_keywords.append(kw)

            if matched_keywords:
                # Truncate very long messages for the index, but keep full text
                preview = text[:500] + "..." if len(text) > 500 else text
                results.append({
                    "line": line_num,
                    "type": msg_type,
                    "role": message.get("role", "unknown"),
                    "keywords": matched_keywords,
                    "preview": preview,
                    "full_length": len(text),
                })

    with open(OUTPUT, "w") as f:
        json.dump(results, f, indent=2)

    print(f"Found {len(results)} matching messages")
    for r in results:
        kws = ", ".join(r["keywords"])
        print(f"  L{r['line']:4d} [{r['type']:9s}] ({kws})")

if __name__ == "__main__":
    main()
