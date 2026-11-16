"""Print snippets around a needle in assistant text of the session transcript (read-only)."""
from __future__ import annotations

import json
import sys

PATH = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d.jsonl"
needle = sys.argv[1]
lo, hi = int(sys.argv[2]), int(sys.argv[3])
width = int(sys.argv[4]) if len(sys.argv) > 4 else 900
with open(PATH, encoding="utf-8", errors="replace") as f:
    for n, line in enumerate(f, 1):
        if n < lo or n > hi or needle not in line:
            continue
        rec = json.loads(line)
        if rec.get("type") != "assistant":
            continue
        content = rec.get("message", {}).get("content")
        texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"] if isinstance(content, list) else [str(content)]
        for t in texts:
            i = t.find(needle)
            while i >= 0:
                print(f"--- L{n} ---")
                print(t[max(0, i - 100): i + width])
                i = t.find(needle, i + 1)
                break
