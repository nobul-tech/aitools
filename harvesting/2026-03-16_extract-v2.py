#!/usr/bin/env python3
"""Extract all user and assistant messages from session transcript with line numbers.

Outputs a condensed view showing message boundaries with line numbers
and the first 500 chars, filtering for messages containing delegation-related keywords.
"""
import json
import sys

TRANSCRIPT = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_eaacf9da.jsonl"

KEYWORDS = [
    "execution protocol",
    "delegation",
    "delegation duty",
    "identity duty",
    "briefing",
    "harness constraint",
    "OPORD",
    "FRAGORD",
    "carry forward",
    "sub-agent",
    "subagent",
    "execution model",
    "delegation brief",
    "delegation model",
]

def extract_text(record):
    """Try multiple paths to get text content."""
    # Direct content
    content = record.get("content", "")
    if isinstance(content, str) and content:
        return content
    if isinstance(content, list):
        texts = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                texts.append(item.get("text", ""))
            elif isinstance(item, str):
                texts.append(item)
        if texts:
            return "\n".join(texts)

    # Nested message
    msg = record.get("message", {})
    if isinstance(msg, dict):
        return extract_text(msg)

    return ""

def get_role(record):
    """Get role from record."""
    t = record.get("type", "")
    if t in ("user", "human"):
        return "USER"
    if t == "assistant":
        return "ASSISTANT"

    msg = record.get("message", {})
    if isinstance(msg, dict):
        role = msg.get("role", "")
        if role in ("user", "human"):
            return "USER"
        if role == "assistant":
            return "ASSISTANT"

    return t.upper() if t else None

def main():
    # First pass: find all lines with keywords
    keyword_lines = []

    with open(TRANSCRIPT, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            text = extract_text(record)
            role = get_role(record)

            if not text or not role:
                continue

            if role not in ("USER", "ASSISTANT"):
                continue

            text_lower = text.lower()
            matched = [kw for kw in KEYWORDS if kw.lower() in text_lower]

            if matched:
                keyword_lines.append({
                    "line": line_num,
                    "role": role,
                    "keywords": matched,
                    "text": text,
                })

    # Output
    for entry in keyword_lines:
        print(f"\n{'='*80}")
        print(f"LINE {entry['line']} | {entry['role']} | Keywords: {', '.join(entry['keywords'])}")
        print(f"Full length: {len(entry['text'])} chars")
        print(f"{'='*80}")
        # Print up to 3000 chars
        if len(entry["text"]) <= 3000:
            print(entry["text"])
        else:
            print(entry["text"][:3000])
            print(f"\n... [TRUNCATED at 3000/{len(entry['text'])} chars]")

if __name__ == "__main__":
    main()
