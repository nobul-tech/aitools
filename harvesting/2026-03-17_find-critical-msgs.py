#!/usr/bin/env python3
"""Extract the exact user messages between 2585-2605 that triggered the .aitools/ decision."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

with open(transcript_path, 'r') as f:
    for line_num, line in enumerate(f, 1):
        if line_num < 2585 or line_num > 2610:
            continue
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get('type', '')
        if msg_type not in ('user', 'assistant'):
            continue

        msg = obj.get('message', {})
        content = msg.get('content', '')

        if isinstance(content, list):
            texts = []
            for block in content:
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'text':
                        texts.append('[TEXT] ' + block.get('text', ''))
                    elif btype == 'thinking':
                        thinking = block.get('thinking', '')
                        texts.append('[THINKING] ' + thinking[:2000])
                    elif btype == 'tool_use':
                        texts.append(f'[TOOL_USE] {block.get("name", "?")}')
                    elif btype == 'tool_result':
                        texts.append(f'[TOOL_RESULT]')
                elif isinstance(block, str):
                    texts.append('[STR] ' + block)
            content = '\n'.join(texts)

        if not isinstance(content, str):
            content = str(content)

        print(f"\n{'='*60}")
        print(f"LINE {line_num} | TYPE: {msg_type}")
        print(f"{'='*60}")
        print(content[:5000])
        print()
