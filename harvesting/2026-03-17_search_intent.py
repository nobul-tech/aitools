#!/usr/bin/env python3
"""Search JSONL transcript files for user messages containing 'intent'."""
import json
import sys

files = [
    '/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl',
    '/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_79b05dd0.jsonl',
    '/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_37ab88e4.jsonl',
    '/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_276dee5c.jsonl',
    '/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_ed02d497.jsonl',
]

for fname in files:
    short = fname.split('/')[-1]
    try:
        with open(fname, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except:
                    continue
                msg_type = obj.get('type', '')
                if msg_type not in ('human', 'queue-operation', 'user'):
                    continue
                # Extract message text
                msg_text = ''
                if 'message' in obj:
                    m = obj['message']
                    if isinstance(m, str):
                        msg_text = m
                    elif isinstance(m, dict):
                        if 'content' in m:
                            c = m['content']
                            if isinstance(c, str):
                                msg_text = c
                            elif isinstance(c, list):
                                for part in c:
                                    if isinstance(part, dict) and part.get('type') == 'text':
                                        msg_text += part.get('text', '') + ' '
                                    elif isinstance(part, str):
                                        msg_text += part + ' '
                if not msg_text and 'content' in obj:
                    c = obj['content']
                    if isinstance(c, str):
                        msg_text = c
                    elif isinstance(c, list):
                        for part in c:
                            if isinstance(part, dict) and part.get('type') == 'text':
                                msg_text += part.get('text', '') + ' '

                if not msg_text:
                    continue

                lower = msg_text.lower()
                if 'intent' in lower:
                    print(f'=== FILE: {short} | LINE: {line_num} | TYPE: {msg_type} | CATEGORY: intent ===')
                    print(msg_text[:5000])
                    print('---END---')
                    print()
    except FileNotFoundError:
        print(f'FILE NOT FOUND: {short}')
