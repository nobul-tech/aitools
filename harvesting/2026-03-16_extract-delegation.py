#!/usr/bin/env python3
"""Extract delegation/execution protocol evolution from session transcript.

Reads a JSONL session file, searches for messages containing key terms,
and outputs the relevant user/assistant messages with line numbers.
"""
import json
import sys
import re

TRANSCRIPT = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_eaacf9da.jsonl"

KEYWORDS = [
    "execution protocol",
    "delegation",
    "delegation duty",
    "identity duty",
    "identity",
    "briefing",
    "harness constraint",
    "recursive",
    "OPORD",
    "FRAGORD",
    "situational awareness",
    "carry forward",
    "carry",
    "subagent",
    "sub-agent",
]

# Focus on lines around the areas of interest
FOCUS_RANGES = [
    (1095, 1120),   # execution protocol first proposed
    (1180, 1200),   # delegation duty born
    (1230, 1250),   # harness constraints on delegation
    (1255, 1275),   # recursive / generalized
    (1265, 1280),   # include the plan / FRAGORD
    (1280, 1320),   # identity duty
    (1340, 1420),   # final protocol
    (1440, 1485),   # final protocol continued
    (85, 105),      # early references
    (955, 975),     # mid-session references
]

def in_focus(line_num: int) -> bool:
    for start, end in FOCUS_RANGES:
        if start <= line_num <= end:
            return True
    return False

def extract_text_content(msg: dict) -> str:
    """Extract text content from a message object."""
    if isinstance(msg, str):
        return msg

    content = msg.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "text":
                    texts.append(item.get("text", ""))
                elif item.get("type") == "tool_result":
                    # skip tool results
                    pass
            elif isinstance(item, str):
                texts.append(item)
        return "\n".join(texts)
    return ""

def get_message_type(record: dict) -> str:
    """Determine if this is a user or assistant message."""
    msg_type = record.get("type", "")
    if msg_type == "user" or msg_type == "human":
        return "USER"
    elif msg_type == "assistant":
        return "ASSISTANT"

    # Check nested message
    message = record.get("message", {})
    if isinstance(message, dict):
        role = message.get("role", "")
        if role == "user" or role == "human":
            return "USER"
        elif role == "assistant":
            return "ASSISTANT"

    return msg_type.upper() if msg_type else "UNKNOWN"

def main():
    results = []

    with open(TRANSCRIPT, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue

            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Get the text content
            text = extract_text_content(record)
            if not text:
                # Try nested message
                message = record.get("message", {})
                if isinstance(message, dict):
                    text = extract_text_content(message)

            if not text:
                continue

            text_lower = text.lower()

            # Check if in focus range and contains any keyword
            matched_keywords = []
            for kw in KEYWORDS:
                if kw.lower() in text_lower:
                    matched_keywords.append(kw)

            if matched_keywords and in_focus(line_num):
                msg_type = get_message_type(record)
                results.append({
                    "line": line_num,
                    "type": msg_type,
                    "keywords": matched_keywords,
                    "text": text[:5000],  # Limit length
                    "full_length": len(text),
                })

    # Output results
    for r in results:
        print(f"\n{'='*80}")
        print(f"LINE {r['line']} | {r['type']} | Keywords: {', '.join(r['keywords'])}")
        print(f"Text length: {r['full_length']}")
        print(f"{'='*80}")
        # Print first 5000 chars
        print(r["text"])
        if r["full_length"] > 5000:
            print(f"\n... [TRUNCATED - {r['full_length']} total chars]")

if __name__ == "__main__":
    main()
