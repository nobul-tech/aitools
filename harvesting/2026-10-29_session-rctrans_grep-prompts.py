#!/usr/bin/env python3
"""Grep commander prompts and AskUserQuestion answers across session JSONL files.

usage: grep-prompts.py --grep RX [--ctx N] [--max N] FILE...
Prints file, timestamp, uuid, the matching prompt/answer (truncated to --max),
and the last --ctx chars of the assistant text before it.
Skips sidechain entries, system reminders, task notifications, compaction
summaries, and agent-message relays.
"""
import argparse
import json
import re
import sys

SKIP_PREFIX = ("<system-reminder>", "<task-notification>", "<local-command", "<command-",
               "This session is being continued", "Another Claude session sent a message",
               "Base directory for this skill")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--grep", required=True)
    ap.add_argument("--ctx", type=int, default=1200)
    ap.add_argument("--max", type=int, default=3000)
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    rx = re.compile(a.grep, re.I)
    hits = 0
    for fn in a.files:
        asks = {}
        last = ""
        try:
            fh = open(fn, encoding="utf-8")
        except OSError as err:
            print(f"WARN {fn}: {err}", file=sys.stderr)
            continue
        with fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if d.get("isSidechain"):
                    continue
                c = (d.get("message") or {}).get("content")
                ts = d.get("timestamp", "?")
                uid = d.get("uuid", "?")
                if d.get("type") == "assistant" and isinstance(c, list):
                    for b in c:
                        if not isinstance(b, dict):
                            continue
                        if b.get("type") == "tool_use" and b.get("name") == "AskUserQuestion":
                            asks[b.get("id")] = json.dumps(b.get("input"))
                        if b.get("type") == "text" and b.get("text", "").strip():
                            last = b["text"]
                    continue
                if d.get("type") != "user":
                    continue
                items = []
                if isinstance(c, str):
                    items.append(("PROMPT", c))
                elif isinstance(c, list):
                    for b in c:
                        if not isinstance(b, dict):
                            continue
                        if b.get("type") == "text":
                            items.append(("PROMPT", b.get("text", "")))
                        elif b.get("type") == "tool_result" and b.get("tool_use_id") in asks:
                            items.append(("ANSWER", "Q: " + asks[b.get("tool_use_id")] + "\nA: " + json.dumps(b.get("content"))))
                for kind, t in items:
                    s = t.strip()
                    if not s or s.startswith(SKIP_PREFIX):
                        continue
                    if not rx.search(s):
                        continue
                    hits += 1
                    print(f"\n######## {kind} {fn.rsplit('/', 1)[-1]} {ts} uuid={uid}")
                    print(f"-- prev assistant (tail): {last[-a.ctx:]}")
                    print(f"-- JOSE: {t[: a.max]}")
    print(f"--- hits: {hits}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
