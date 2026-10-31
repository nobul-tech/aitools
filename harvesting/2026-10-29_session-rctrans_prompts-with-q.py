#!/usr/bin/env python3
"""Print main-thread commander prompts and AskUserQuestion answers in a window,
each preceded by the last assistant text before it.

usage: prompts-with-q.py FILE START END [--q-chars N] [--p-chars N]
Skips sidechain entries, tool_results that are not AskUserQuestion answers,
system-reminder blocks, and task-notification entries (flagged, not printed).
"""
import argparse
import json
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("file")
    ap.add_argument("start")
    ap.add_argument("end")
    ap.add_argument("--q-chars", type=int, default=6000)
    ap.add_argument("--p-chars", type=int, default=20000)
    a = ap.parse_args()
    asks = {}
    last_asst = ""
    last_asst_ts = ""
    skipped = 0
    with open(a.file, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            try:
                d = json.loads(line)
            except json.JSONDecodeError as err:
                print(f"WARN line {n}: {err}", file=sys.stderr)
                continue
            if d.get("isSidechain"):
                continue
            ts = d.get("timestamp") or ""
            uuid = d.get("uuid") or "?"
            msg = d.get("message") or {}
            content = msg.get("content")
            in_win = a.start <= ts <= a.end
            if d.get("type") == "assistant" and isinstance(content, list):
                for c in content:
                    if not isinstance(c, dict):
                        continue
                    if c.get("type") == "tool_use" and c.get("name") == "AskUserQuestion":
                        asks[c.get("id")] = json.dumps(c.get("input"))
                    if c.get("type") == "text" and c.get("text", "").strip():
                        last_asst = c["text"]
                        last_asst_ts = ts
            elif d.get("type") == "user" and in_win:
                texts = []
                if isinstance(content, str):
                    texts.append(content)
                elif isinstance(content, list):
                    for c in content:
                        if not isinstance(c, dict):
                            continue
                        if c.get("type") == "tool_result" and c.get("tool_use_id") in asks:
                            r = c.get("content")
                            print(f"\n######## ANSWER {ts} uuid={uuid}")
                            print("ASK:", asks[c.get("tool_use_id")][: a.q_chars])
                            print("ANSWER:", json.dumps(r)[: a.p_chars])
                        elif c.get("type") == "text":
                            texts.append(c.get("text", ""))
                for t in texts:
                    s = t.strip()
                    if not s or s.startswith("<system-reminder>"):
                        continue
                    if s.startswith("<task-notification>") or s.startswith("<local-command") or s.startswith("<command-"):
                        skipped += 1
                        continue
                    print(f"\n######## PROMPT {ts} uuid={uuid}")
                    print(f"-- preceding assistant text ({last_asst_ts}), last {a.q_chars} chars:")
                    print(last_asst[-a.q_chars:])
                    print("-- JOSE:")
                    print(t[: a.p_chars])
    print(f"--- skipped notifications/commands: {skipped}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
