#!/usr/bin/env python3
"""Check every quote in a brief verbatim against the session transcript prompts and issue #180.

Usage: check_quotes.py <brief.json>
Checks each item's `quote` and every double-quoted span inside `source.location`.
Corpus: prompts.txt (commander prompts, dbd05b0c) + body.md + comment-*.md (issue #180).
"""
import json, pathlib, re, sys

d = pathlib.Path(__file__).parent / "data"
prompts = (d / "prompts.txt").read_text(encoding="utf-8")
issue = (d / "body.md").read_text(encoding="utf-8") + "\n" + "\n".join(
    (d / f"comment-{i}.md").read_text(encoding="utf-8") for i in range(1, 6))

def where(q: str) -> str:
    hits = []
    if q in prompts:
        hits.append("transcript")
    if q in issue:
        hits.append("issue")
    if hits:
        return "VERBATIM(" + ",".join(hits) + ")"
    norm = lambda s: re.sub(r"\s+", " ", s)
    if norm(q) in norm(prompts) or norm(q) in norm(issue):
        return "WHITESPACE-DIFF"
    return "NOT FOUND"

brief = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for node in ("objectives", "decisions", "assumptions", "ambiguities", "constraints", "operational_learning"):
    for it in brief.get(node, []):
        iid = it.get("id", it.get("text", "")[:30])
        q = it.get("quote")
        if q:
            parts = [p.strip() for p in q.split("…")] if "…" in q else [q]
            for p in parts:
                print(f"{node:12} {iid:10} quote    {where(p):24} {p[:70]!r}")
        loc = (it.get("source") or {}).get("location", "")
        # double-quoted spans in location, honouring nested quotes poorly: take maximal "..." (issue convention)
        for m in re.finditer(r'(?<![A-Za-z])"(.+?)"(?=[ ,.;)]|\s*\(|$)', loc):
            span = m.group(1)
            if len(span) < 8:
                continue
            print(f"{node:12} {iid:10} location {where(span):24} {span[:70]!r}")
