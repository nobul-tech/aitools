"""Replace the '## Open questions' section of an issue body with a new section file."""
import sys

body_path, section_path = sys.argv[1], sys.argv[2]
body = open(body_path, encoding="utf-8").read()
section = open(section_path, encoding="utf-8").read()
start = body.index("## Open questions")
end = body.index("## Sources")
open(body_path, "w", encoding="utf-8").write(body[:start] + section + body[end:])
print("replaced", end - start, "chars with", len(section))
