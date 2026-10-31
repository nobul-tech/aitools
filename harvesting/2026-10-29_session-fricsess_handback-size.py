#!/usr/bin/env python3
"""Count subagent hand-backs, task notifications and AskUserQuestion calls that
reached the main thread of a session JSONL, with their total characters.

usage: handback-size.py <jsonl>
"""
import json
import sys


def main() -> int:
    counts = {"handback": [0, 0], "task-notification": [0, 0], "typed": [0, 0],
              "ask": [0, 0], "compact": [0, 0]}
    with open(sys.argv[1], encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            try:
                e = json.loads(line)
            except json.JSONDecodeError as err:
                print(f"WARN line {n}: {err}", file=sys.stderr)
                continue
            if e.get("isSidechain"):
                continue
            msg = e.get("message", {}) or {}
            c = msg.get("content")
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "AskUserQuestion":
                        counts["ask"][0] += 1
                texts = [b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text"]
                c = "\n".join(texts) if texts and e.get("type") == "user" else None
            if e.get("type") != "user" or not isinstance(c, str) or not c:
                continue
            if c.startswith("Another Claude session sent a message"):
                k = "handback"
            elif c.startswith("<task-notification>"):
                k = "task-notification"
            elif c.startswith("This session is being continued"):
                k = "compact"
            elif c.startswith("<") or c.startswith("Base directory"):
                continue
            else:
                k = "typed"
            counts[k][0] += 1
            counts[k][1] += len(c)
    for k, (num, chars) in counts.items():
        print(f"{k}: {num} messages, {chars} chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
