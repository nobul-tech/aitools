#!/usr/bin/env python3
"""find-in-sessions.py -- print user/assistant text messages that match a regex.

Usage:
  python3 find-in-sessions.py [--role user|assistant|both] [--max N] [--window N]
                              PATTERN FILE [FILE ...]

For each matching message prints: file, line, timestamp, role, length, and the
text (the whole text when it is at most --max characters, else --window
characters on each side of the first match). Tool calls and tool results are
skipped. The match count goes to stderr.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def message_texts(obj: dict) -> list[str]:
    msg = obj.get("message")
    if not isinstance(msg, dict):
        return []
    content = msg.get("content")
    if isinstance(content, str):
        return [content]
    texts: list[str] = []
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text")
                if isinstance(text, str):
                    texts.append(text)
    return texts


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("pattern")
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument("--role", choices=["user", "assistant", "both"], default="both")
    parser.add_argument("--max", type=int, default=4000)
    parser.add_argument("--window", type=int, default=1500)
    parser.add_argument(
        "--human",
        action="store_true",
        help="skip injected user-role text (skills, task notifications, commands, reminders)",
    )
    args = parser.parse_args()
    injected = (
        "Base directory for this skill",
        "<task-notification>",
        "<local-command",
        "<command-name>",
        "<system-reminder>",
        "Caveat:",
        "[Request interrupted",
    )
    rx = re.compile(args.pattern, re.IGNORECASE)
    roles = {"user", "assistant"} if args.role == "both" else {args.role}
    hits = 0
    for path in args.files:
        try:
            fh = path.open(encoding="utf-8")
        except OSError as exc:
            print(f"ERROR cannot open {path}: {exc}", file=sys.stderr)
            continue
        with fh:
            for lineno, raw in enumerate(fh, 1):
                try:
                    obj = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                role = obj.get("type")
                if role not in roles:
                    continue
                for text in message_texts(obj):
                    if args.human and (obj.get("isMeta") or text.lstrip().startswith(injected)):
                        continue
                    match = rx.search(text)
                    if not match:
                        continue
                    hits += 1
                    stamp = obj.get("timestamp", "?")
                    print(f"=== {path.name} line {lineno} | {stamp} | {role} | {len(text)} chars")
                    if len(text) <= args.max:
                        print(text)
                    else:
                        lo = max(0, match.start() - args.window)
                        hi = min(len(text), match.end() + args.window)
                        print(f"[excerpt {lo}-{hi}]")
                        print(text[lo:hi])
                    print()
    print(f"matches: {hits}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
