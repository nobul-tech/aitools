#!/usr/bin/env python3
"""Extract ALL user messages from the transcript, with line numbers."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

with open(transcript_path, 'r') as f:
    for line_num, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        if obj.get('type') != 'user':
            continue

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

        if not content or not content.strip():
            continue

        print(f"\n{'='*80}")
        print(f"LINE {line_num} | USER MESSAGE")
        print(f"{'='*80}")
        print(content[:5000])
        if len(content) > 5000:
            print(f"\n... [truncated, total {len(content)} chars]")
        print()
