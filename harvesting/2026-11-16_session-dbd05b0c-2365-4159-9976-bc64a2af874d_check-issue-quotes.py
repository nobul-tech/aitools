"""Check the quotes of decision rows D874d-<first>..<last> in an issue body against the transcript.

Usage: check-issue-quotes.py <transcript.jsonl> <body file> <first n> <last n>
Every double-quoted span in the row's source column must appear verbatim in a user record.
Exits 1 on any miss.
"""
import json
import re
import sys

transcript, body_path, first, last = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
texts = []
for line in open(transcript, encoding="utf-8"):
    try:
        rec = json.loads(line)
    except json.JSONDecodeError:
        continue
    if rec.get("type") == "queue-operation" and isinstance(rec.get("content"), str):
        texts.append(rec["content"])  # a message the commander sent while a turn was running
        continue
    if rec.get("type") != "user":
        continue
    c = rec.get("message", {}).get("content", "")
    if isinstance(c, list):
        c = "\n".join(p.get("text", "") if isinstance(p, dict) else "" for p in c)
    texts.append(c)
corpus = "\n".join(texts)

bad = 0
for row in open(body_path, encoding="utf-8").read().splitlines():
    m = re.match(r"^\| D874d-(\d+) \| .* \| (.*) \|$", row)
    if not m or not (first <= int(m.group(1)) <= last):
        continue
    for q in re.findall(r': "(.*?)"(?= \||$| and )', m.group(2) + " |"):
        ok = q in corpus
        bad += not ok
        print("OK  " if ok else "MISS", f"D874d-{m.group(1)}", repr(q[:70]))
print("problems:", bad)
sys.exit(1 if bad else 0)
