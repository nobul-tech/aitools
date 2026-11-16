"""Replace the text between two headings of a Markdown file with a section file.

Usage: splice-sections.py <body.md> <start heading> <end heading> <section file>
The start heading is replaced; the end heading is kept.
"""
import sys

body_path, start_h, end_h, section_path = sys.argv[1:5]
body = open(body_path, encoding="utf-8").read()
section = open(section_path, encoding="utf-8").read()
start = body.index(start_h)
end = body.index(end_h)
open(body_path, "w", encoding="utf-8").write(body[:start] + section + body[end:])
print("replaced", end - start, "chars with", len(section))
