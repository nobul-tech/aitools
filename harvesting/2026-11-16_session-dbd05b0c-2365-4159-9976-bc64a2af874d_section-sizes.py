"""Print the character count of each '## ' section of a Markdown file.

Usage: section-sizes.py <file>
"""
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
parts = re.split(r"(?m)^(?=## )", text)
for p in parts:
    lines = p.splitlines()
    print(len(p), repr(lines[0][:70] if lines else ""))
print("total", len(text))
