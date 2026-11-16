#!/usr/bin/env python3
"""Split issue180.json into body.md and comment-N.md files."""
import json, pathlib
d = pathlib.Path(__file__).parent / "data"
j = json.loads((d / "issue180.json").read_text())
(d / "body.md").write_text(j["body"])
for i, c in enumerate(j["comments"], 1):
    (d / f"comment-{i}.md").write_text(f"author: {c['author']['login']} created: {c['createdAt']}\n\n{c['body']}")
print(j["title"], j["updatedAt"], len(j["comments"]))
