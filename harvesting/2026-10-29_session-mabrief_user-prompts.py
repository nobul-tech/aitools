#!/usr/bin/env python3
"""List the commander's typed prompts (not tool results, not sidechain) from a
Claude Code session JSONL, newest first, plus AskUserQuestion answers.

usage: user-prompts.py <jsonl> [--limit N] [--max-chars N] [--after TS]
"""
import argparse
import json
import sys


def text_of(content) -> str:
    if isinstance(content, str):
        return content
    parts = []
    if isinstance(content, list):
        for b in content:
            if isinstance(b, dict):
                if b.get("type") == "text":
                    parts.append(b.get("text", ""))
                elif "content" in b:
                    parts.append(text_of(b["content"]))
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("jsonl")
    ap.add_argument("--limit", type=int, default=50)
    ap.add_argument("--max-chars", type=int, default=4000)
    ap.add_argument("--after", default=None)
    a = ap.parse_args()
    items = []
    asks = {}
    with open(a.jsonl, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            try:
                e = json.loads(line)
            except json.JSONDecodeError as err:
                print(f"WARN line {n}: {err}", file=sys.stderr)
                continue
            if e.get("isSidechain"):
                continue
            ts = e.get("timestamp", "?")
            if a.after and ts < a.after:
                continue
            msg = e.get("message", {})
            content = msg.get("content")
            if e.get("type") == "user" and msg.get("role") == "user":
                if isinstance(content, str):
                    items.append((ts, n, "PROMPT", content))
                    continue
                if isinstance(content, list):
                    texts = [b.get("text", "") for b in content
                             if isinstance(b, dict) and b.get("type") == "text"]
                    for b in content:
                        if (isinstance(b, dict) and b.get("type") == "tool_result"
                                and b.get("tool_use_id") in asks):
                            items.append((ts, n, "ANSWER", asks[b["tool_use_id"]]
                                          + "\n-> " + text_of(b.get("content"))))
                    if texts and not any(isinstance(b, dict) and b.get("type") == "tool_result"
                                         for b in content):
                        items.append((ts, n, "PROMPT", "\n".join(texts)))
            if isinstance(content, list):
                for b in content:
                    if (isinstance(b, dict) and b.get("type") == "tool_use"
                            and b.get("name") == "AskUserQuestion"):
                        asks[b.get("id")] = json.dumps(b.get("input", {}))[:1500]
    items.reverse()
    print(f"--- {len(items)} items", file=sys.stderr)
    for ts, n, kind, t in items[: a.limit]:
        print(f"=== {kind} {ts} line={n} chars={len(t)}")
        print(t[: a.max_chars])
    return 0


if __name__ == "__main__":
    sys.exit(main())
