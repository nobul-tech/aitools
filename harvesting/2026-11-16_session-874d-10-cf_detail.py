#!/usr/bin/env python3
"""detail.py -- print record metadata and full visible (non-thinking) text for chosen lines.

Never prints content parts of type thinking/redacted_thinking; reports only their count.
Usage: python3 detail.py <transcript.jsonl> <line> [<line> ...]
"""
import json
import sys


def main() -> None:
    path = sys.argv[1]
    want = {int(x) for x in sys.argv[2:]}
    with open(path, encoding="utf-8") as f:
        for ln, raw in enumerate(f, 1):
            if ln not in want:
                continue
            rec = json.loads(raw)
            meta = {k: v for k, v in rec.items() if k != "message"}
            print(f"=== L{ln} top-level (minus message): {json.dumps(meta, ensure_ascii=False)[:3000]}")
            msg = rec.get("message")
            if isinstance(msg, dict):
                mmeta = {k: v for k, v in msg.items() if k != "content"}
                print(f"    message meta: {json.dumps(mmeta, ensure_ascii=False)}")
                content = msg.get("content")
                if isinstance(content, str):
                    print(f"    text(full): {content}")
                elif isinstance(content, list):
                    kinds = [p.get("type") for p in content if isinstance(p, dict)]
                    print(f"    part types: {kinds}")
                    for p in content:
                        if not isinstance(p, dict):
                            continue
                        if p.get("type") in ("thinking", "redacted_thinking"):
                            continue
                        if p.get("type") == "text":
                            print(f"    text(full): {p.get('text')}")
                        elif p.get("type") == "tool_use":
                            print(f"    tool_use(full): {json.dumps(p.get('input'), ensure_ascii=False)}")
                        elif p.get("type") == "tool_result":
                            c = p.get("content")
                            if isinstance(c, list):
                                c = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
                            print(f"    tool_result(full): {c}")


if __name__ == "__main__":
    main()
