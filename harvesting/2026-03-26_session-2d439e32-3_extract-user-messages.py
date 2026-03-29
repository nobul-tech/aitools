#!/usr/bin/env python3
"""Extract Jose's messages about aitools identity and mission control from session transcripts."""
import json
import sys

def extract_from_file(filepath, keywords):
    """Extract user messages matching keywords from a JSONL session file."""
    user_messages = []
    with open(filepath, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            if obj.get("type") == "user":
                msg = obj.get("message", "")
                # Handle different message formats
                if isinstance(msg, dict):
                    content = msg.get("content", "")
                    if isinstance(content, list):
                        texts = []
                        for block in content:
                            if isinstance(block, dict) and block.get("type") == "text":
                                texts.append(block.get("text", ""))
                            elif isinstance(block, str):
                                texts.append(block)
                        msg = "\n".join(texts)
                    elif isinstance(content, str):
                        msg = content
                    else:
                        msg = str(content)
                elif isinstance(msg, list):
                    texts = []
                    for part in msg:
                        if isinstance(part, dict) and part.get("type") == "text":
                            texts.append(part.get("text", ""))
                    msg = " ".join(texts)

                if msg and len(msg.strip()) > 5:
                    user_messages.append((line_num, msg.strip()))

    print(f"Total user messages with content: {len(user_messages)}")
    print("---")

    matched = 0
    for line_num, msg in user_messages:
        msg_lower = msg.lower()
        if any(kw.lower() in msg_lower for kw in keywords):
            matched += 1
            print(f"\n=== LINE {line_num} ===")
            print(msg[:1500])
            if len(msg) > 1500:
                print(f"... [{len(msg)} total chars]")

    print(f"\n--- Matched {matched} of {len(user_messages)} messages ---")


keywords = [
    'aitools is', 'aitools should', 'mission control', 'self-learning', 'self-improving',
    'provenance', 'harness', 'what i want', 'long term', 'long-term', 'my time',
    'no mvp', 'no versioning', 'next session', 'no next session',
    'leverage', 'delegation', 'commander', 'continuously evolving',
    'foundation', 'knowledge system', 'the point of', 'the purpose of',
    'value my time', 'tokens', 'overhead', 'agent output',
    'operational learning', 'self aware', 'self-aware',
    'i value', 'what this is', 'what it is', 'the whole point',
    'single session', 'sessions work', 'context runs out',
    'rewind', 'nobulai', 'dashboard', 'communication channel',
    'bidirectional', 'feedback loop', 'flat organization',
    'there is no', 'directive', 'authoritative',
    'this tool', 'this project', 'what we are building',
    'time is', 'time more than'
]

filepath = sys.argv[1] if len(sys.argv) > 1 else "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-24_c0dc2ddc.jsonl"
extract_from_file(filepath, keywords)
