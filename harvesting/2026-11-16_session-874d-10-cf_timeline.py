#!/usr/bin/env python3
"""timeline.py -- walk a Claude Code subagent JSONL and print a timeline.

Skips every content part of type 'thinking' (content never read or printed;
only its count per record is reported). Prints, per line: line number,
record type, timestamp, and for assistant records the visible text and
tool_use calls; for user records the tool_result (truncated) or text.

Usage: python3 timeline.py <transcript.jsonl> [maxchars]
"""
import json
import sys


def short(s: str, n: int) -> str:
    s = s.replace("\n", "\\n")
    return s if len(s) <= n else s[:n] + f"...[+{len(s) - n} chars]"


def main() -> None:
    path = sys.argv[1]
    maxc = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    with open(path, encoding="utf-8") as f:
        for ln, raw in enumerate(f, 1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw)
            except json.JSONDecodeError as e:
                print(f"L{ln} PARSE-ERROR {e}")
                continue
            rtype = rec.get("type")
            ts = rec.get("timestamp", "")
            extra = []
            for k in ("isApiErrorMessage", "error", "subtype", "level", "isMeta", "toolUseResult"):
                if k in rec and k != "toolUseResult":
                    extra.append(f"{k}={short(str(rec[k]), 120)}")
            msg = rec.get("message") or {}
            if isinstance(msg, dict):
                if msg.get("stop_reason"):
                    extra.append(f"stop_reason={msg.get('stop_reason')}")
                if msg.get("model"):
                    extra.append(f"model={msg.get('model')}")
                usage = msg.get("usage")
                if isinstance(usage, dict):
                    extra.append(
                        "usage(in={},cache_read={},cache_create={},out={})".format(
                            usage.get("input_tokens"),
                            usage.get("cache_read_input_tokens"),
                            usage.get("cache_creation_input_tokens"),
                            usage.get("output_tokens"),
                        )
                    )
            print(f"L{ln} [{rtype}] {ts} {' '.join(extra)}")
            if rtype == "queue-operation" or rtype == "system":
                c = rec.get("content")
                if c is not None:
                    print(f"    content: {short(str(c), maxc)}")
            content = msg.get("content") if isinstance(msg, dict) else None
            if isinstance(content, str):
                print(f"    text: {short(content, maxc)}")
                continue
            if not isinstance(content, list):
                continue
            nthink = 0
            for part in content:
                if not isinstance(part, dict):
                    continue
                pt = part.get("type")
                if pt in ("thinking", "redacted_thinking"):
                    nthink += 1
                    continue
                if pt == "text":
                    print(f"    text: {short(part.get('text', ''), maxc)}")
                elif pt == "tool_use":
                    inp = json.dumps(part.get("input", {}), ensure_ascii=False)
                    print(f"    tool_use {part.get('name')} id={part.get('id')}: {short(inp, maxc)}")
                elif pt == "tool_result":
                    c = part.get("content")
                    if isinstance(c, list):
                        txt = " ".join(
                            x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text"
                        )
                    else:
                        txt = str(c)
                    err = " ERROR" if part.get("is_error") else ""
                    print(f"    tool_result{err} id={part.get('tool_use_id')} len={len(txt)}: {short(txt, maxc)}")
                else:
                    print(f"    part type={pt}")
            if nthink:
                print(f"    (thinking parts skipped: {nthink})")


if __name__ == "__main__":
    main()
