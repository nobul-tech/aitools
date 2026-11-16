"""Print the refusal metadata of chosen JSONL lines, never their content parts.

Usage: refusal-meta.py <transcript.jsonl> <line>...
Prints type, requestId, stop_reason, stop_details and the content part types only.
"""
import json
import sys

path, wanted = sys.argv[1], {int(x) for x in sys.argv[2:]}
for n, line in enumerate(open(path, encoding="utf-8"), 1):
    if n not in wanted:
        continue
    r = json.loads(line)
    m = r.get("message", {}) if isinstance(r.get("message"), dict) else {}
    parts = m.get("content")
    kinds = [p.get("type") for p in parts] if isinstance(parts, list) else type(parts).__name__
    print(n, r.get("type"), r.get("requestId"), m.get("stop_reason"), json.dumps(m.get("stop_details")), kinds)
