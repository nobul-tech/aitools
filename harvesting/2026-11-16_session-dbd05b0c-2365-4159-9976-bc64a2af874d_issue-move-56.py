"""Move sections 5 and 6 of issue #180 body v5.4 verbatim into a comment; leave pointer stubs.

Usage: issue-move-56.py <v5.4 body> <out body> <out comment>
"""
import sys

src, out_body, out_comment = sys.argv[1:4]
body = open(src, encoding="utf-8").read()
s5 = "## 5. Standards and specs in the harness"
s7 = "## 7. Implementation"
for a in (s5, s7):
    if body.count(a) != 1:
        print(f"FAIL: anchor {a!r}", file=sys.stderr)
        sys.exit(1)
i5, i7 = body.index(s5), body.index(s7)
moved = body[i5:i7]
i6 = moved.index("## 6. Assumptions and ambiguities")
sec5_title = moved[: moved.index("\n")]
STUBS = (
    f"{sec5_title}\n\n"
    "In the comment \"Sections 5 and 6 (moved in v5.4)\", verbatim (moved to keep this body under GitHub's "
    "size limit).\n\n"
    "## 6. Assumptions and ambiguities\n\n"
    "In the comment \"Sections 5 and 6 (moved in v5.4)\", verbatim. Every point this section left to the RFC "
    "is settled in RFC 0011 section 4.\n\n"
)
new_body = body[:i5] + STUBS + body[i7:]
comment = (
    "## Sections 5 and 6 (moved in v5.4)\n\n"
    "Moved from the issue body (v5.4, session dbd05b0c), verbatim, to keep the body under GitHub's size "
    "limit.\n\n" + moved.rstrip() + "\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n"
)
open(out_body, "w", encoding="utf-8").write(new_body)
open(out_comment, "w", encoding="utf-8").write(comment)
print("body:", len(new_body), "chars; comment:", len(comment), "chars; section 6 at", i6)
