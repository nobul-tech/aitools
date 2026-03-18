#!/usr/bin/env python3
"""Find ALL user messages between lines 2540 and 2600."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

with open(transcript_path, 'r') as f:
    for line_num, line in enumerate(f, 1):
        if line_num < 2540 or line_num > 2602:
            continue
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
                    elif btype == 'tool_result':
                        texts.append(f'[TOOL_RESULT: {block.get("tool_use_id", "?")}]')
                elif isinstance(block, str):
                    texts.append(block)
            content = '\n'.join(texts)

        if not isinstance(content, str):
            content = str(content)

        # Skip empty/tool-result only messages
        clean = content.replace('[TOOL_RESULT:', '').strip()
        if not clean or clean.startswith('[TOOL_RESULT'):
            continue

        print(f"\n{'='*60}")
        print(f"LINE {line_num} | USER MESSAGE")
        print(f"{'='*60}")
        print(content[:5000])
        print()
