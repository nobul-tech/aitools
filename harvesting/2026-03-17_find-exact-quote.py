#!/usr/bin/env python3
"""Search for the exact quote attributed to the user in Decision #34.
Quote: 'Mission Command and Mission Analysis: this is stuff we want to give to our users'
Also: '.channel should instead be .aitools/channels or something like that'
"""
import json
import re

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

# Several fragments to search for
FRAGMENTS = [
    'give to our users',
    'stuff we want to give',
    'should instead be',
    '.aitools/channels',
    '.aitools/channel',
    '.aitools/scratch',
    '.scratch should',
    'Mission Command and Mission Analysis',
    'something like that',
    'something we want to give',
]

with open(transcript_path, 'r') as f:
    for line_num, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get('type', '')
        if msg_type != 'user':
            continue

        msg = obj.get('message', {})
        content = msg.get('content', '')

        if isinstance(content, list):
            texts = []
            for block in content:
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'text':
                        texts.append(block.get('text', ''))
                elif isinstance(block, str):
                    texts.append(block)
            content = '\n'.join(texts)

        if not isinstance(content, str):
            continue

        for frag in FRAGMENTS:
            if frag.lower() in content.lower():
                print(f"\nFOUND '{frag}' at LINE {line_num}")
                print(f"FULL MESSAGE:")
                print(content[:5000])
                print()
                break
