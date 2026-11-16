#!/usr/bin/env python3
"""Print the lines of the issue #180 body (from issue180.json) matching a regex, with line numbers.

Usage: grep-issue.py <regex> [context]
"""
import json
import re
import sys

issue = json.load(open("/Users/new-jose/repos/aitools/.scratch/session-874d-5-brf/issue180.json", encoding="utf-8"))
lines = issue["body"].split("\n")
pat = re.compile(sys.argv[1])
ctx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
for i, l in enumerate(lines, 1):
    if pat.search(l):
        for j in range(max(1, i - ctx), min(len(lines), i + ctx) + 1):
            print("%d: %s" % (j, lines[j - 1][:400]))
        if ctx:
            print("--")
