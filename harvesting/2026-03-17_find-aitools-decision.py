#!/usr/bin/env python3
"""Find the exact user message that triggered .aitools/ namespace decision."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

# The agent at line 2595 says "Now addressing your message — you're right on both points"
# and discusses ".aitools/ namespace for user-level features"
# We need the user message that came between lines 2580 and 2595

with open(transcript_path, 'r') as f:
    for line_num, line in enumerate(f, 1):
        if line_num < 2575 or line_num > 2600:
            continue
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get('type', '')
        msg = obj.get('message', {})
        content = msg.get('content', '')

        if isinstance(content, list):
            texts = []
            for block in content:
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'text':
                        texts.append(block.get('text', ''))
                    elif btype == 'thinking':
                        texts.append('[THINKING] ' + block.get('thinking', '')[:500])
                elif isinstance(block, str):
                    texts.append(block)
            content = '\n'.join(texts)

        print(f"\nLINE {line_num} | TYPE: {msg_type}")
        if msg_type in ('user', 'assistant'):
            if isinstance(content, str):
                print(content[:3000])
        else:
            print(f"  (type: {msg_type})")
        print()
