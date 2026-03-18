#!/usr/bin/env python3
"""Extract agent thinking blocks between lines 2595-2610."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

with open(transcript_path, 'r') as f:
    for line_num, line in enumerate(f, 1):
        if line_num < 2595 or line_num > 2615:
            continue
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get('type', '')
        if msg_type != 'assistant':
            continue

        msg = obj.get('message', {})
        content = msg.get('content', [])

        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'thinking':
                        thinking = block.get('thinking', '')
                        print(f"\n{'='*60}")
                        print(f"LINE {line_num} | THINKING ({len(thinking)} chars)")
                        print(f"{'='*60}")
                        print(thinking[:10000])
                        print()
                    elif btype == 'text':
                        text = block.get('text', '')
                        print(f"\n{'='*60}")
                        print(f"LINE {line_num} | TEXT ({len(text)} chars)")
                        print(f"{'='*60}")
                        print(text[:3000])
                        print()
