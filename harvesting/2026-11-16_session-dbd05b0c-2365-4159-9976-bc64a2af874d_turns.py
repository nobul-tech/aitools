"""List the commander's prompts in a session JSONL, or dump a span of lines as readable text.

Usage:
  turns.py <jsonl> list
  turns.py <jsonl> dump <first line> <last line> <out file>
Line numbers are 1-based JSONL lines.
"""
import json
import sys

CAP = 600


def text_of(content) -> str:
    if isinstance(content, str):
        return content
    parts = []
    for p in content:
        if not isinstance(p, dict):
            continue
        t = p.get("type")
        if t == "text":
            parts.append(p.get("text", ""))
        elif t == "thinking":
            parts.append("[THINKING]\n" + p.get("thinking", ""))
        elif t == "tool_use":
            s = json.dumps(p.get("input", {}), ensure_ascii=False)
            parts.append("[TOOL_USE " + p.get("name", "") + "] " + (s if len(s) <= CAP else s[:CAP] + f" ...[+{len(s) - CAP} chars]"))
        elif t == "tool_result":
            c = p.get("content", "")
            if isinstance(c, list):
                c = "\n".join(x.get("text", "") for x in c if isinstance(x, dict))
            c = str(c)
            parts.append("[TOOL_RESULT] " + (c if len(c) <= CAP else c[:CAP] + f" ...[+{len(c) - CAP} chars]"))
    return "\n".join(parts)


def is_prompt(rec) -> bool:
    if rec.get("type") != "user" or rec.get("isMeta") or rec.get("isCompactSummary"):
        return False
    c = rec.get("message", {}).get("content", "")
    if isinstance(c, list):
        if any(isinstance(p, dict) and p.get("type") == "tool_result" for p in c):
            return False
        c = text_of(c)
    return bool(c.strip()) and not c.lstrip().startswith("<")


path, mode = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().splitlines()
if mode == "list":
    for i, line in enumerate(lines, 1):
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if is_prompt(rec):
            print(i, rec.get("timestamp", ""), repr(text_of(rec["message"]["content"])[:150]))
        elif rec.get("isCompactSummary") or rec.get("type") == "system" and rec.get("subtype") == "compact_boundary":
            print(i, rec.get("timestamp", ""), "== COMPACTION ==")
    print("total lines", len(lines))
else:
    first, last, out = int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
    with open(out, "w", encoding="utf-8") as f:
        for i in range(first, last + 1):
            try:
                rec = json.loads(lines[i - 1])
            except json.JSONDecodeError:
                continue
            t = rec.get("type")
            if t not in ("user", "assistant"):
                continue
            body = text_of(rec.get("message", {}).get("content", ""))
            if body.strip():
                f.write(f"\n===== L{i} {t} {rec.get('timestamp', '')} =====\n{body}\n")
    print("wrote", out)
