#!/usr/bin/env python3
"""Extract ONLY human messages from the 40-agent session transcript."""
import json

transcript = "/Users/pepe/.claude/projects/-Users-pepe-repos-aitools/e059186f-45b2-461b-a4ba-e33cd23f9ee1.jsonl"
output = "/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/40agent-human-messages.md"

messages = []
with open(transcript, 'r') as f:
    for lineno, line in enumerate(f, 1):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("isSidechain", False):
            continue
        if obj.get("type") != "human":
            continue
        content = obj.get("message", {}).get("content", [])
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text", "").strip()
                if len(text) > 10:
                    ts = obj.get("timestamp", "")
                    messages.append(f"## L{lineno} ({ts})\n\n{text}\n")

with open(output, 'w') as f:
    f.write(f"# Human Messages from Session Z1IhGrcgGO\n\n")
    f.write(f"{len(messages)} human messages extracted (sidechains excluded)\n\n---\n\n")
    for msg in messages:
        f.write(msg + "\n---\n\n")

print(f"{len(messages)} human messages -> {output}")
