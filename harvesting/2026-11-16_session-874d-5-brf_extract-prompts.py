#!/usr/bin/env python3
"""Extract the commander's prompts (user text messages) from a Claude Code session JSONL.

Usage: extract-prompts.py <transcript.jsonl> <out.json>
Writes {line_number: text} for every user record whose content carries text
(plain string or text blocks), and for tool_result blocks that look like
AskUserQuestion answers. Never prints the transcript.
"""
import json
import sys


def text_of(content):
    if isinstance(content, str):
        return content
    parts = []
    if isinstance(content, list):
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text":
                parts.append(block.get("text", ""))
    return "\n".join(parts)


def main() -> int:
    src, out = sys.argv[1], sys.argv[2]
    found = {}
    with open(src, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("type") != "user":
                continue
            msg = rec.get("message") or {}
            t = text_of(msg.get("content"))
            if t.strip():
                found[n] = t
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(found, fh, indent=1, ensure_ascii=False)
    print("user text records:", len(found))
    print("lines:", sorted(found)[:60])
    return 0


if __name__ == "__main__":
    sys.exit(main())
