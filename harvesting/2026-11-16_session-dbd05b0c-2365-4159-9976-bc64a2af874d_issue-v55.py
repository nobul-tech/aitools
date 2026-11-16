"""Build issue #180 body v5.5 from v5.4: decisions D874d-71 to D874d-74 (the briefs directory).

Usage: issue-v55.py <v5.4 body> <out body> <out comment>
The version-history paragraphs older than v5.4 move verbatim to a comment, so the body stays
under GitHub's 65,536-character limit. Every replacement must match once; any miss exits 1.
"""
import sys

src, out_body, out_comment = sys.argv[1:4]
body = open(src, encoding="utf-8").read()


def once(old: str, new: str) -> None:
    global body
    n = body.count(old)
    if n != 1:
        print(f"FAIL: expected 1 match, found {n}: {old[:80]!r}", file=sys.stderr)
        sys.exit(1)
    body = body.replace(old, new)


T = "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/dbd05b0c-2365-4159-9976-bc64a2af874d.jsonl"

# 1. Version history: keep v5.4 in the body, move v5.3 and older to a comment.
start = body.index("v5.3 (2026-11-16, session dbd05b0c)")
end = body.index("**How to read the citations**")
history = body[start:end].rstrip()
body = body[:start] + ("Earlier versions (v5.3 to v1.0) are described in the comment \"Body version history "
                       "(moved in v5.5)\", verbatim.\n\n") + body[end:]
once(
    "**Body version.** v5.4 (2026-11-16, session dbd05b0c)",
    "**Body version.** v5.5 (2026-11-16, session dbd05b0c), from the commander's prompt of L4045: decisions "
    "D874d-71 to D874d-74 in section 1. A mission brief resides in the session scratch directory by default; a "
    "brief whose mission outlives its session resides, on the commander's order, in the tracked `<repo>/briefs/` "
    "(sections 2 and 3; RFC 0011 v1.3, 3.3.1). The version history before v5.4 moved to a comment, verbatim. "
    "Sections changed in this version are marked *Changed in v5.5*.\n\n"
    "v5.4 (2026-11-16, session dbd05b0c)",
)

# 2. Decisions table: four rows after D874d-70.
ROWS = [
    ("D874d-71", "Only the implementing mission's brief moves to the briefs directory: `briefs/874d-2-structured-reports-brief.json`", "L4045, on R874d-44", "44) just this one"),
    ("D874d-72", "The briefs directory is tracked in git, as plans are", "L4045, on R874d-45", "45) add briefs to git, plans too."),
    ("D874d-73", "A mission brief resides in the session scratch directory by default, since most briefs are ephemeral; it resides in the briefs directory only on the commander's order", "L4045", "briefs should live in scratch by default because most of othem are ephemeral, but if i order them to live in briefs they can live there."),
    ("D874d-74", "The briefs directory, `<repo>/briefs/`, is the location for briefs with a long lifecycle, such as the brief of a mission that implements a roadmap item", "L4045", "document the locatino of briefs/ as a location where briefs that have a long lifecycle need to live, like roadmap items."),
]
anchor = "| D874d-70 | "
i = body.index(anchor)
if body.count(anchor) != 1:
    print("FAIL: D874d-70 row", file=sys.stderr)
    sys.exit(1)
e = body.index("\n", i)
body = body[:e] + "".join(
    f'\n| {d} | {t} | 2026-11-16 | commander | Session dbd05b0c {loc}: "{q}" |' for d, t, loc, q in ROWS) + body[e:]

# 3. Section 2: a row for the long-lifecycle location.
row_start = body.index("| Mission brief file | ")
row_end = body.index("\n", row_start)
body = (body[:row_end] + "\n| Mission brief file, long lifecycle | `<repo>/briefs/<mission name>-brief.json`, "
        "tracked in git; only on the commander's order, for a brief whose mission outlives the session that wrote "
        "it, such as a roadmap item. *Changed in v5.5* | `briefs/874d-2-structured-reports-brief.json` | "
        "D874d-71 to D874d-74 |" + body[row_end:])

# 4. Section 3: the mission brief's location.
once(
    "at `<session scratch dir>/<mission name>-brief.json` (D874d-42, section 2). The delegation prompt gives its path",
    "at `<session scratch dir>/<mission name>-brief.json` (D874d-42, section 2); on the commander's order, a brief "
    "whose mission outlives its session resides in `<repo>/briefs/` instead, tracked in git (D874d-73, D874d-74; "
    "*Changed in v5.5*). The delegation prompt gives its path",
)

comment = ("## Body version history (moved in v5.5)\n\n"
           "Moved from the issue body (v5.5, session dbd05b0c), verbatim, to keep the body under GitHub's size "
           "limit.\n\n" + history + "\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n")
open(out_body, "w", encoding="utf-8").write(body)
open(out_comment, "w", encoding="utf-8").write(comment)
print("body:", len(body), "chars; comment:", len(comment), "chars")
if len(body) > 65000:
    print("FAIL: body over 65,000 characters", file=sys.stderr)
    sys.exit(1)
