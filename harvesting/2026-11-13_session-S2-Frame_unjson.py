"""Decode a JSON string file (from chrome-devtools evaluate_script) into plain text."""
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    text = json.load(f)
with open(dst, "w", encoding="utf-8") as f:
    f.write(text)
print(f"wrote {dst}: {len(text)} chars")
