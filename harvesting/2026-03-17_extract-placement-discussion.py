#!/usr/bin/env python3
"""Extract messages specifically about channel/aitools placement decisions."""
import json
import re

# More targeted keywords for the placement decision
PLACEMENT_KEYWORDS = re.compile(
    r'\.channel|channel.dir|\.aitools/channel|\.aitools/scratch|'
    r'repo.root|user.level|per.platform|user-level|repo-level|'
    r'~\/\.aitools|workspace.feature|\.aitools/|'
    r'mission.command|mission.analysis|briefing|planning.brief|'
    r'running.estimate|inter.agent|give.to.our.users|'
    r'\.aitools\b',
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

        if PLACEMENT_KEYWORDS.search(content):
            # For user messages, always show full text (they're shorter)
            if msg_type == 'user':
                print(f"\n{'='*80}")
                print(f"LINE {line_num} | USER")
                print(f"{'='*80}")
                print(content[:8000])
                if len(content) > 8000:
                    print(f"\n... [truncated, total {len(content)} chars]")
                print()
            else:
                # For assistant, show context around matches
                matches = list(PLACEMENT_KEYWORDS.finditer(content))
                if not matches:
                    continue

                print(f"\n{'='*80}")
                print(f"LINE {line_num} | ASSISTANT (total {len(content)} chars)")
                print(f"{'='*80}")

                if len(content) < 8000:
                    print(content)
                else:
                    shown_ranges = []
                    for m in matches:
                        start = max(0, m.start() - 500)
                        end = min(len(content), m.end() + 500)
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
