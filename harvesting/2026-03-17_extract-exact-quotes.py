#!/usr/bin/env python3
"""Extract exact user messages at specific line numbers from the transcript."""
import json

transcript_path = "/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_b8a9ed4e.jsonl"

# Key lines to extract full content from
# Based on our analysis, the critical moments are:
# Line 1505: User first mentions .channel directory
# Lines around 2590-2610: The .aitools/ namespace decision
# Lines around 2690-2701: Final state

# Let's extract ALL user messages and their line numbers, then the agent responses
# at the key decision points

target_lines = [1505, 1507, 1521, 1528, 1538, 1544, 1552, 1581, 2466, 2471,
                2505, 2511, 2534, 2542, 2570, 2580, 2595, 2602, 2607, 2638,
                2685, 2690, 2696, 2701]

# Also search for any user message containing ".aitools" or "user level" or "repo root"
import re
USER_PLACEMENT_RE = re.compile(
    r'\.aitools|repo.root|user.level|repo.level|user level|'
    r'repo level|per.platform|~\/\.|user-level|repo-level|'
    r'give to our users|workspace|\.scratch.should|\.channel.should|'
    r'Mission Command and Mission Analysis',
    re.IGNORECASE
)

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
                elif isinstance(block, str):
                    texts.append(block)
            content = '\n'.join(texts)

        if not isinstance(content, str):
            continue

        show = False
        reason = ""

        if line_num in target_lines:
            show = True
            reason = "TARGET LINE"
        elif msg_type == 'user' and USER_PLACEMENT_RE.search(content):
            show = True
            reason = f"USER MSG WITH PLACEMENT KEYWORD"

        if show:
            print(f"\n{'#'*80}")
            print(f"LINE {line_num} | TYPE: {msg_type} | REASON: {reason}")
            print(f"{'#'*80}")
            # Show full content for user messages, truncated for assistant
            if msg_type == 'user':
                print(content)
            else:
                if len(content) < 6000:
                    print(content)
                else:
                    print(content[:3000])
                    print(f"\n... [TRUNCATED - total {len(content)} chars] ...\n")
                    print(content[-2000:])
            print()
