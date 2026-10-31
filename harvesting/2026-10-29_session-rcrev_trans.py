#!/usr/bin/env python3
"""Print user prompts / tool_result answers for given uuids, and any user entries after a cutoff."""
import json
import sys

path = sys.argv[1]
uuids = set(sys.argv[2].split(",")) if len(sys.argv) > 2 and sys.argv[2] else set()
after = sys.argv[3] if len(sys.argv) > 3 else None


def text_of(msg) -> str:
    c = msg.get("content")
    if isinstance(c, str):
        return c
    out = []
    for part in c or []:
        if isinstance(part, dict):
            if part.get("type") == "text":
                out.append(part.get("text", ""))
            elif part.get("type") == "tool_result":
                cc = part.get("content")
                if isinstance(cc, list):
                    out.append("[tool_result] " + " ".join(x.get("text", "") for x in cc if isinstance(x, dict)))
                else:
                    out.append("[tool_result] " + str(cc))
    return "\n".join(out)


with open(path, encoding="utf-8") as fh:
    for line in fh:
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        if e.get("type") != "user":
            continue
        u = e.get("uuid", "")
        ts = e.get("timestamp", "")
        t = text_of(e.get("message", {}))
        hit = any(u.startswith(x) for x in uuids)
        late = after is not None and ts > after and ("[tool_result]" not in t or "User has answered" in t or "answered your questions" in t)
        if hit or (late and not t.startswith("[tool_result]")) or (late and "answered" in t):
            print(f"=== {ts} {u}")
            print(t[:3000])
