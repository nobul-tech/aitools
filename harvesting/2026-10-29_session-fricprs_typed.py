#!/usr/bin/env python3
"""From prompts.txt, print only commander-typed prompts (no task notifications or agent messages) matching friction keywords."""
import re
txt = open("/Users/new-jose/repos/aitools/.scratch/session-fricprs/prompts.txt").read()
items = re.split(r"(?m)^(=== (?:PROMPT|ANSWER) .*)$", txt)
kw = re.compile(r"worktree|draft|merg|review|stack|conflict|overhead|friction|why|again|ci/cd|ci |broke|stale|rebase|squash", re.I)
for i in range(1, len(items), 2):
    head, body = items[i], items[i + 1].strip()
    if head.startswith("=== ANSWER"):
        continue
    if body.startswith("<task-notification") or body.startswith("Another Claude session") or "[Subagent hand-back]" in body[:400]:
        continue
    if kw.search(body):
        print(head)
        print(body[:900])
        print()
