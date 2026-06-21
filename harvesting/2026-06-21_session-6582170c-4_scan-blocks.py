#!/usr/bin/env python3
"""Scan hook event logs for hook_block events (claude-code-guide vs Explore)."""
import json, glob

paths = glob.glob('/Users/new-jose/repos/aitools/.scratch/**/events.jsonl', recursive=True)
paths += glob.glob('/Users/new-jose/repos/aitools/harvesting/*events.jsonl')

blocks = {}
for p in paths:
    try:
        with open(p) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    e = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if e.get('type') == 'hook_block':
                    d = e.get('d', {})
                    key = (e.get('src', ''), json.dumps(d) if isinstance(d, dict) else str(d))
                    blocks[key] = blocks.get(key, 0) + 1
    except OSError as ex:
        print('ERR', p, ex)

print('files scanned:', len(paths))
print('block events by (src, detail):')
for k, v in sorted(blocks.items()):
    print(f'  {v:4d}  {k}')
