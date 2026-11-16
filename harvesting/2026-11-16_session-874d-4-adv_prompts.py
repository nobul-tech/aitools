"""Print the commander's prompts at given transcript lines (read-only, line-by-line)."""
from __future__ import annotations

import json
import sys

PATH = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d.jsonl"
WANT = {int(x) for x in sys.argv[1:]}
with open(PATH, encoding="utf-8", errors="replace") as f:
    for n, line in enumerate(f, 1):
        if n not in WANT:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            print(f"L{n}: not JSON")
            continue
        msg = rec.get("message", {})
        content = msg.get("content")
        if isinstance(content, list):
            parts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
            content = "\n".join(parts)
        print(f"===== L{n} {rec.get('type')} {rec.get('timestamp')} =====")
        print(content)
