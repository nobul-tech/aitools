#!/usr/bin/env python3
"""Extract ALL content blocks between lines 2580-2600 to find the thinking that led to .aitools/."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

with open(transcript_path, 'r') as f:
    for line_num, line in enumerate(f, 1):
        if line_num < 2580 or line_num > 2600:
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
            for i, block in enumerate(content):
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'thinking':
                        thinking = block.get('thinking', '')
                        if thinking:
                            print(f"\nLINE {line_num} | THINKING block {i} ({len(thinking)} chars)")
                            print(thinking[:10000])
                    elif btype == 'text':
                        text = block.get('text', '')
                        if text:
                            print(f"\nLINE {line_num} | TEXT block {i} ({len(text)} chars)")
                            print(text[:3000])
                    elif btype == 'tool_use':
                        name = block.get('name', '?')
                        inp = block.get('input', {})
                        print(f"\nLINE {line_num} | TOOL_USE block {i}: {name}")
                        # Show key parts of input
                        if name in ('Edit', 'Write'):
                            fp = inp.get('file_path', '?')
                            print(f"  file: {fp}")
                            old = inp.get('old_string', '')
                            new = inp.get('new_string', '')
                            content_str = inp.get('content', '')
                            if old:
                                print(f"  old: {old[:200]}")
                            if new:
                                print(f"  new: {new[:200]}")
                            if content_str:
                                print(f"  content: {content_str[:500]}")
