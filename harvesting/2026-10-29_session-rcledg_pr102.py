#!/usr/bin/env python3
"""Print PR 102 body, comments, reviews, commits in readable form."""
import json, sys
d = json.load(open(sys.argv[1]))
print("STATE", d["state"], "mergeable", d["mergeable"], d["mergeStateStatus"], "head", d["headRefName"])
print("=== BODY ===")
print(d["body"])
for c in d["comments"]:
    print("=== COMMENT", c["author"]["login"], c["createdAt"], "===")
    print(c["body"])
for r in d["reviews"]:
    print("=== REVIEW", r["author"]["login"], r["state"], r.get("submittedAt"), "===")
    print(r["body"])
for c in d["commits"]:
    print("COMMIT", c["oid"][:7], c["messageHeadline"], [a.get("login") for a in c["authors"]])
