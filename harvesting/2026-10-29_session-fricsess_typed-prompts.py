#!/usr/bin/env python3
"""List only the commander's typed prompts and AskUserQuestion answers from one
or more Claude Code session JSONL files, newest first. Drops subagent
hand-backs, task notifications, skill bodies, compaction summaries and local
command echoes.

usage: typed-prompts.py [--max-chars N] [--grep REGEX] <jsonl>...
"""
import argparse
import json
import re
import sys

SKIP = ("Another Claude session sent a message", "<task-notification>",
        "Base directory for this skill", "This session is being continued",
        "<local-command", "<command-name>", "<system-reminder>",
        "Caveat: The messages below", "[Request interrupted")


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


def scan(path: str, out: list) -> None:
    asks = {}
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            try:
                e = json.loads(line)
            except json.JSONDecodeError as err:
                print(f"WARN {path}:{n}: {err}", file=sys.stderr)
                continue
            if e.get("isSidechain"):
                continue
            ts = e.get("timestamp", "?")
            msg = e.get("message", {}) or {}
            content = msg.get("content")
            if isinstance(content, list):
                for b in content:
                    if (isinstance(b, dict) and b.get("type") == "tool_use"
                            and b.get("name") == "AskUserQuestion"):
                        qs = b.get("input", {}).get("questions", [])
                        if not isinstance(qs, list):
                            qs = [qs]
                        asks[b.get("id")] = " | ".join(
                            q.get("question", "") if isinstance(q, dict) else str(q)
                            for q in qs)[:600]
            if e.get("type") != "user" or msg.get("role") != "user":
                continue
            if isinstance(content, str):
                t = content.strip()
                if t and not t.startswith(SKIP):
                    out.append((ts, path, n, "PROMPT", t))
                continue
            if isinstance(content, list):
                has_tr = False
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_result":
                        has_tr = True
                        if b.get("tool_use_id") in asks:
                            ans = text_of(b.get("content"))
                            m = re.search(r"The user answered: (.*?)Read the answers", ans, re.S)
                            out.append((ts, path, n, "ANSWER",
                                        "Q: " + asks[b["tool_use_id"]] + "\n-> " + (m.group(1) if m else ans)))
                if not has_tr:
                    t = "\n".join(b.get("text", "") for b in content
                                  if isinstance(b, dict) and b.get("type") == "text").strip()
                    if t and not t.startswith(SKIP):
                        out.append((ts, path, n, "PROMPT", t))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--max-chars", type=int, default=2500)
    ap.add_argument("--grep", default=None)
    a = ap.parse_args()
    out = []
    for p in a.files:
        scan(p, out)
    out.sort(key=lambda x: x[0], reverse=True)
    rx = re.compile(a.grep, re.I) if a.grep else None
    k = 0
    for ts, p, n, kind, t in out:
        if rx and not rx.search(t):
            continue
        k += 1
        short = p.rsplit("/", 1)[-1]
        print(f"=== {kind} {ts} {short}:{n}")
        print(t[: a.max_chars])
    print(f"--- {k} items", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
