"""Verify every quoted string in the issue body's decision table.

Quotes from session dbd05b0c must appear verbatim in the transcript line the row cites
(L79, L289, ...). Other quotes must appear verbatim in the reference corpus (issue
body v2.0 and the issue comments, which hold the 87795dc3 and March quotes).

Usage: verify-decision-quotes.py <transcript.jsonl> <body.md> <corpus file>...
"""
import json
import re
import sys

transcript_path, body_path, corpus_paths = sys.argv[1], sys.argv[2], sys.argv[3:]

lines = open(transcript_path, encoding="utf-8").read().splitlines()


def user_text(n: int) -> str:
    rec = json.loads(lines[n - 1])
    content = rec.get("message", {}).get("content", "")
    if isinstance(content, list):
        return "\n".join(p.get("text", "") for p in content if isinstance(p, dict))
    return content


session_lines = {}
for n in (79, 289, 565, 907, 1275, 1665, 1921, 2160, 2442):
    session_lines[n] = user_text(n)
corpus = "\n".join(open(p, encoding="utf-8").read() for p in corpus_paths)

failures = 0
checked = 0
for row in open(body_path, encoding="utf-8").read().splitlines():
    if not row.startswith("| D874d-"):
        continue
    rid = row.split("|")[1].strip()
    cited = [int(x) for x in re.findall(r"\bL(\d+)\b", row) if int(x) in session_lines]
    source_col = row.split("|")[5] if row.count("|") >= 6 else row
    for seg in re.findall(r'"([^"]+)"', source_col):
        seg = seg.strip()
        if len(seg) < 12:
            continue
        checked += 1
        where = [n for n in cited if seg in session_lines[n]]
        if where:
            continue
        other = [n for n in session_lines if seg in session_lines[n]]
        if other:
            failures += 1
            print(f"WRONG LINE {rid}: found on L{other}, row cites {cited}: {seg[:70]!r}")
            continue
        if seg in corpus:
            print(f"corpus    {rid}: {seg[:70]!r}")
            continue
        failures += 1
        print(f"NOT FOUND {rid}: {seg[:90]!r}")
print(f"checked {checked} quoted segments; {failures} not found")
sys.exit(1 if failures else 0)
