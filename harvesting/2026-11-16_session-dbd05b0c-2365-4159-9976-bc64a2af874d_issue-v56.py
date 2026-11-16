"""Build issue #180 body v5.6 from v5.5: decisions D874d-75 to D874d-77.

Usage: issue-v56.py <v5.5 body> <out body>
Every replacement must match once; the body must stay under 65,536 characters.
"""
import sys

src, out = sys.argv[1], sys.argv[2]
body = open(src, encoding="utf-8").read()


def once(old, new):
    global body
    if body.count(old) != 1:
        print(f"FAIL: {body.count(old)} matches: {old[:80]!r}", file=sys.stderr)
        sys.exit(1)
    body = body.replace(old, new)


once("**Body version.** v5.5 (2026-11-16, session dbd05b0c)",
     "**Body version.** v5.6 (2026-11-16, session dbd05b0c), from the commander's prompt of L4523: decisions "
     "D874d-75 to D874d-77 in section 1. RFC 0011 is at v1.5.\n\n"
     "v5.5 (2026-11-16, session dbd05b0c)")
ROWS = [
    ("D874d-75", "The consistency review of RFC 0011, stopped by an API safeguard, is relaunched fresh on Sonnet with high effort", "L4523, on R874d-46", "46) yes, relaunch fresh, yes try sonnet 5.5 1M context with high effot"),
    ("D874d-76", "Whether a brief in the briefs directory goes to `main` directly, as plans do, is deferred; the question is not raised again", "L4523, on R874d-47", "47) ignore this, dont ask again its deferred"),
    ("D874d-77", "The two safeguard refusals are reported to Anthropic as a possible false positive; the session agent drafts the report", "L4523, on R874d-48", "48) sure but im not doing it"),
]
anchor = "| D874d-74 | "
i = body.index(anchor)
e = body.index("\n", i)
body = body[:e] + "".join(
    f'\n| {d} | {t} | 2026-11-16 | commander | Session dbd05b0c {loc}: "{q}" |' for d, t, loc, q in ROWS) + body[e:]
open(out, "w", encoding="utf-8").write(body)
print("body:", len(body), "chars")
if len(body) > 65536:
    print("FAIL: over GitHub's limit", file=sys.stderr)
    sys.exit(1)
