"""Check every quote in mission briefs: verbatim in the session's user prompts or the issue corpus.

Usage: check-brief-quotes.py <transcript.jsonl> <corpus file> <brief.json>...
Prints each empty or unmatched quote; exits 1 if any.
"""
import json
import sys

transcript, corpus_path, briefs = sys.argv[1], sys.argv[2], sys.argv[3:]
prompts = []
for line in open(transcript, encoding="utf-8"):
    try:
        rec = json.loads(line)
    except json.JSONDecodeError:
        continue
    if rec.get("type") == "queue-operation" and isinstance(rec.get("content"), str):
        prompts.append(rec["content"])  # a message the commander sent while a turn was running
        continue
    if rec.get("type") != "user":
        continue
    content = rec.get("message", {}).get("content", "")
    if isinstance(content, list):
        content = "\n".join(p.get("text", "") for p in content if isinstance(p, dict))
    prompts.append(content)
corpus = "\n".join(prompts) + "\n" + open(corpus_path, encoding="utf-8").read()

bad = 0
checked = 0


def walk(node, where):
    global bad, checked
    if isinstance(node, dict):
        if "quote" in node:
            q = node["quote"]
            ident = node.get("id", where)
            if not q:
                if node.get("source", {}).get("kind") == "commander":
                    bad += 1
                    print(f"EMPTY     {where} {ident}")
            else:
                for seg in q.split(" … "):
                    checked += 1
                    if seg not in corpus:
                        bad += 1
                        print(f"NOT FOUND {where} {ident}: {seg[:80]!r}")
        for k, v in node.items():
            walk(v, where)
    elif isinstance(node, list):
        for v in node:
            walk(v, where)


for path in briefs:
    walk(json.load(open(path, encoding="utf-8")), path.rsplit("/", 1)[-1])
print(f"checked {checked} quote segments; {bad} problems")
sys.exit(1 if bad else 0)
