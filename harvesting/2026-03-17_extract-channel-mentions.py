#!/usr/bin/env python3
"""Extract messages mentioning channel/aitools placement from JSONL transcript."""
import json
import re
import sys

KEYWORDS = re.compile(
    r'\.?channel|\.aitools|repo.root|user.level|per.platform|'
    r'\.scratch|user-level|repo-level|~/\.aitools|workspace|'
    r'user.home|home.dir|per.machine|per.user',
    re.IGNORECASE
)

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

        msg_type = obj.get('type', '')
        if msg_type not in ('user', 'assistant'):
            continue

        msg = obj.get('message', {})
        content = msg.get('content', '')

        # Extract text content
        if isinstance(content, list):
            texts = []
            for block in content:
                if isinstance(block, dict):
                    btype = block.get('type', '')
                    if btype == 'text':
                        texts.append(block.get('text', ''))
                    elif btype == 'thinking':
                        texts.append('[THINKING] ' + block.get('thinking', ''))
                elif isinstance(block, str):
                    texts.append(block)
            content = '\n'.join(texts)

        if not isinstance(content, str):
            continue

        if KEYWORDS.search(content):
            matches = list(KEYWORDS.finditer(content))
            if not matches:
                continue

            print(f"\n{'='*80}")
            print(f"LINE {line_num} | TYPE: {msg_type}")
            print(f"{'='*80}")

            # If message is short enough, show it all
            if len(content) < 5000:
                print(content)
            else:
                # Show context around each match
                shown_ranges = []
                for m in matches:
                    start = max(0, m.start() - 300)
                    end = min(len(content), m.end() + 300)
                    if shown_ranges and start <= shown_ranges[-1][1]:
                        shown_ranges[-1] = (shown_ranges[-1][0], end)
                    else:
                        shown_ranges.append((start, end))

                for i, (start, end) in enumerate(shown_ranges):
                    if i > 0:
                        print("\n  [...]\n")
                    prefix = "..." if start > 0 else ""
                    suffix = "..." if end < len(content) else ""
                    print(f"  {prefix}{content[start:end]}{suffix}")

            print()
