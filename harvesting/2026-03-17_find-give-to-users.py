#!/usr/bin/env python3
"""Find the user message mentioning 'give to our users' and '.aitools' and 'channels'."""
import json
import re

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

# Search for key phrases
PATTERNS = re.compile(
    r'give to our users|\.aitools|user.level|scratch.should|'
    r'user level|users across|all projects|workspace|'
    r'Mission Command and Mission Analysis|'
    r'\.channel.should|\.scratch.should|instead be',
    re.IGNORECASE
)

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

        if PATTERNS.search(content):
            print(f"\n{'='*60}")
            print(f"LINE {line_num} | USER MESSAGE")
            print(f"{'='*60}")
            print(content[:5000])
            print()
