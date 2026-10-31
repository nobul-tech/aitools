#!/usr/bin/env python3
"""Dump text / tool_use input of JSONL entries in a line range (non-sidechain).

usage: dump-lines.py <jsonl> <start> <end> [--role assistant|user|any] [--max-chars N]
"""
import argparse
import json
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("jsonl")
    ap.add_argument("start", type=int)
    ap.add_argument("end", type=int)
    ap.add_argument("--role", default="any")
    ap.add_argument("--max-chars", type=int, default=20000)
    ap.add_argument("--tools", default="AskUserQuestion")
    a = ap.parse_args()
    tools = set(a.tools.split(","))
    with open(a.jsonl, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            if n < a.start or n > a.end:
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError as err:
                print(f"WARN line {n}: {err}", file=sys.stderr)
                continue
            if e.get("isSidechain"):
                continue
            msg = e.get("message", {})
            role = msg.get("role", "")
            if a.role != "any" and role != a.role:
                continue
            content = msg.get("content")
            if isinstance(content, str):
                print(f"=== line {n} {role} {e.get('timestamp')}\n{content[:a.max_chars]}")
                continue
            if not isinstance(content, list):
                continue
            for b in content:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "text" and b.get("text", "").strip():
                    print(f"=== line {n} {role} text {e.get('timestamp')}\n{b['text'][:a.max_chars]}")
                elif b.get("type") == "tool_use" and b.get("name") in tools:
                    print(f"=== line {n} {role} tool_use {b.get('name')} {e.get('timestamp')}\n"
                          + json.dumps(b.get("input"), indent=1)[:a.max_chars])
    return 0


if __name__ == "__main__":
    sys.exit(main())
