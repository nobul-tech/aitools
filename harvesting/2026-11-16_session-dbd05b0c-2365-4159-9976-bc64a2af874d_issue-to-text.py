"""Render a `gh issue view --json title,state,body,comments,updatedAt` dump as plain text.

Usage: issue-to-text.py <in.json> <out file>
"""
import json
import sys

src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src, encoding="utf-8"))
with open(out, "w", encoding="utf-8") as f:
    f.write(f"# {d['title']} ({d['state']}, updated {d['updatedAt']})\n\n===== BODY =====\n{d['body']}\n")
    for i, c in enumerate(d.get("comments", []), 1):
        f.write(f"\n===== COMMENT {i}: {c['author']['login']} {c['createdAt']} =====\n{c['body']}\n")
print("comments:", len(d.get("comments", [])))
