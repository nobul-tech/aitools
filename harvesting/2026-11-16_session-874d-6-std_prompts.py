"""Print the commander's prompts at given transcript lines (1-based), read-only."""
import json
import sys

path = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d.jsonl"
want = {int(x) for x in sys.argv[1:]}
with open(path, encoding="utf-8") as f:
    for n, line in enumerate(f, 1):
        if n not in want:
            continue
        rec = json.loads(line)
        msg = rec.get("message", {})
        content = msg.get("content")
        if isinstance(content, list):
            content = "\n".join(c.get("text", "") for c in content if isinstance(c, dict))
        print(f"== L{n} {rec.get('timestamp')}\n{content}\n")
