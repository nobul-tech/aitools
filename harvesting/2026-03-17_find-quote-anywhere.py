#!/usr/bin/env python3
"""Search for Decision #34 quote fragments in ALL message types (user + assistant + thinking)."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

FRAGMENTS = [
    'give to our users',
    'stuff we want to give',
    'should instead be',
    '.aitools/channels',
    '.aitools/scratch',
    'Mission Command and Mission Analysis: this is stuff',
    'something we want to give to our users',
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
        if msg_type not in ('user', 'assistant'):
            continue

        msg = obj.get('message', {})
        content = msg.get('content', '')

        # Extract ALL text including thinking
        all_text = ''
        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'text':
                        all_text += block.get('text', '') + '\n'
                    elif btype == 'thinking':
                        all_text += block.get('thinking', '') + '\n'
                    elif btype == 'tool_use':
                        inp = block.get('input', {})
                        if isinstance(inp, dict):
                            for v in inp.values():
                                if isinstance(v, str):
                                    all_text += v + '\n'
                elif isinstance(block, str):
                    all_text += block + '\n'
        elif isinstance(content, str):
            all_text = content

        for frag in FRAGMENTS:
            if frag.lower() in all_text.lower():
                print(f"\nFOUND '{frag}' at LINE {line_num} (type: {msg_type})")
                # Find context around the match
                idx = all_text.lower().find(frag.lower())
                start = max(0, idx - 200)
                end = min(len(all_text), idx + len(frag) + 200)
                print(f"CONTEXT: ...{all_text[start:end]}...")
                print()
