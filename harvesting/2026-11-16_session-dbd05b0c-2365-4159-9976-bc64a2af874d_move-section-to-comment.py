"""Move one section of an issue body into a comment file, verbatim, leaving a pointer.

Usage: move-section-to-comment.py <body.md> <start heading> <end heading> <comment.md> <comment title>
The section runs from <start heading> up to (not including) <end heading>.
"""
import sys

body_path, start_h, end_h, comment_path, title = sys.argv[1:6]
body = open(body_path, encoding="utf-8").read()
start = body.index(start_h)
end = body.index(end_h)
section = body[start:end]
section_text = section[len(start_h):].strip("\n")
comment = (
    f"## {title}\n\n"
    "Moved from the issue body (v5.1, session dbd05b0c), verbatim, to keep the body "
    "under GitHub's size limit.\n\n"
    f"{section_text}\n\n"
    "🤖 Generated with [Claude Code](https://claude.com/claude-code)\n"
)
pointer = (
    f"{start_h}\n\n"
    f"In the comment \"{title}\", verbatim (moved in v5.1 to keep this body under "
    "GitHub's size limit).\n\n"
)
open(comment_path, "w", encoding="utf-8").write(comment)
open(body_path, "w", encoding="utf-8").write(body[:start] + pointer + body[end:])
print("moved", len(section), "chars; comment", len(comment), "chars")
