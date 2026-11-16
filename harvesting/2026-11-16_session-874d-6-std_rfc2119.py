"""List RFC 2119 keyword uses and lowercase normative words in RFC 0011 (read-only)."""
import re

path = "/Users/new-jose/repos/aitools/rfcs/RFC-0011-structured-reports.md"
kw = re.compile(r"\b(MUST NOT|MUST|REQUIRED|SHALL NOT|SHALL|SHOULD NOT|SHOULD|RECOMMENDED|MAY|OPTIONAL)\b")
low = re.compile(r"\b(must|shall|should|required|never|is not|are not|no \w+ is)\b")
counts = {}
with open(path, encoding="utf-8") as f:
    for n, line in enumerate(f, 1):
        for m in kw.findall(line):
            counts[m] = counts.get(m, 0) + 1
        if n > 66 and low.search(line):
            print(f"lower L{n}: {line.rstrip()[:160]}")
print(counts)
