#!/usr/bin/env python3
"""Read specific user messages from continuation session."""
import json

path = '/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_79b05dd0.jsonl'
target_lines = [507, 835]

with open(path) as f:
    for i, line in enumerate(f, 1):
        if i not in target_lines:
            continue
        obj = json.loads(line.strip())
        if obj.get('type') == 'user':
            msg = obj.get('message', {})
            content = msg.get('content', '')
            if isinstance(content, list):
                texts = []
                for block in content:
                    if isinstance(block, dict) and block.get('type') == 'text':
                        texts.append(block.get('text', ''))
                    elif isinstance(block, str):
                        texts.append(block)
                content = '\n'.join(texts)
            print(f'LINE {i} FULL USER MESSAGE:')
            print(content[:3000])
            print()
