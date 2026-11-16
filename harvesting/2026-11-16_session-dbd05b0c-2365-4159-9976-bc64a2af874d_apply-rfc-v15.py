"""Apply mission 874d-11's proposals and the session agent's own pass to RFC 0011 v1.4, making v1.5.

Usage: apply-rfc-v15.py <rfc.md> <874d-11 aar.json>
Phase 1: each 874d-11 proposal 'line <n>: <old> -> <new>' is applied where <old> starts on line <n>,
bottom-up, with the exclusions and overrides below. Phase 2: the session agent's own edits, each
<old> occurring exactly once. All or nothing: on any miss nothing is written.
"""
import json
import re
import sys

rfc_path, aar_path = sys.argv[1], sys.argv[2]
text = open(rfc_path, encoding="utf-8").read()
aar = json.load(open(aar_path, encoding="utf-8"))

# Kept out: renaming the placeholder <session scratch dir> would break consistency with D874d-42's
# wording and issue #180; section 2 defines the placeholder instead (phase 2).
EXCLUDE = {"PRO-55", "PRO-69", "PRO-103", "PRO-104"}
# New text replaced: the issue becomes body v5.6 with D874d-75 to D874d-77; this version is v1.5;
# 874d-11's RFI 4 (prose after the block) and RFI 5 (kind of migrated refs) settled here.
OVERRIDE = {
    "PRO-1": "body v5.6 |",
    "PRO-2": "| **Version** | v1.5 |\n| **Author(s)** | Session agent dbd05b0c, with the commander (Jose) |",
    "PRO-3": "It states as normative text the commander's decisions recorded in issue #180 (D874d-1 to D874d-77), and settles",
    "PRO-62": "followed by `json` and nothing else; the block ends",
    "PRO-77": "- Before schema 5 ships, the session agent writes none of them to the DB (3.6.11).",
    "PRO-92": "and `NULL` for the other types; the `refs` column becomes rows of the `refs` table, each with `kind` `observation`",
    "PRO-110": "At v1.5 of this RFC, the working copies of `shared/rules/delegation.md` (D-DEL10) and `shared/skills/delegate/SKILL.md` name the brief `<sid4>_<mission name>-brief.md` in Markdown and do not say that the hand-back is JSON.",
    "PRO-122": "At v1.5 of this RFC, the single export `.aitools/channel/running-estimate.json` is tracked:",
    "PRO-129": "body v5.6: decisions D874d-1 to D874d-77 (section 1), naming (section 2), schema (section 3), store (section 4), implementation (section 7).",
    "PRO-130": "\"Sections 5 and 6 (moved in v5.4)\" (the standards and specs, and the assumptions and ambiguities), \"Body version history (moved in v5.5)\" and \"Commander's decisions on the analysis type and the AAR node (2026-11-15)\".",
    "PRO-133": "This table lists every decision of issue #180 section 1 (D874d-1 to D874d-77). A note writes \"-22\" for D874d-22. \"Superseded\" means",
}

lines = text.split("\n")
starts, pos = [], 0
for ln in lines:
    starts.append(pos)
    pos += len(ln) + 1

edits = []
for p in aar["proposals"]:
    if p["id"] in EXCLUDE:
        continue
    m = re.match(r"^line (\d+): (.*?) -> (.*)$", p["what"], re.S)
    if not m:
        print(f"FAIL parse {p['id']}", file=sys.stderr)
        sys.exit(1)
    n, old, new = int(m.group(1)), m.group(2), m.group(3)
    new = OVERRIDE.get(p["id"], new)
    s = starts[n - 1]
    idx = text.find(old, s)
    if idx < 0 or idx > s + len(lines[n - 1]):
        print(f"FAIL {p['id']}: old not on line {n}: {old[:70]!r}", file=sys.stderr)
        sys.exit(1)
    edits.append((idx, len(old), new, p["id"]))

edits.sort(key=lambda e: e[0], reverse=True)
for (a, b), (c, d) in zip([(e[0], e[1]) for e in edits[1:]], [(e[0], e[1]) for e in edits[:-1]]):
    if a + b > c:
        print("FAIL overlapping edits", file=sys.stderr)
        sys.exit(1)
for idx, ln, new, pid in edits:
    text = text[:idx] + new + text[idx + ln:]
print("phase 1:", len(edits), "proposals applied")

OWN = [
    # version history
    ("""touched a line. The route to `main` of a brief in the briefs directory is
deferred by the commander (D874d-76).""",
     """touched a line. The route to `main` of a brief in the briefs directory is
deferred by the commander (D874d-76).
v1.5 (2026-11-16), session dbd05b0c: consistency and formal register,
reviewed line by line by mission 874d-11 (the relaunch of 874d-8, which an
API safeguard stopped); its proposals are applied, and the session agent's
own pass. Decisions D874d-75 to D874d-77 (L4523)."""),
    # section 2: the placeholder (instead of PRO-55, PRO-69, PRO-103, PRO-104)
    ("- **Session scratch directory:** `<repo>/.scratch/session-<session id>/` of the top-level session.",
     "- **Session scratch directory:** `<repo>/.scratch/session-<session id>/` of the top-level session, written `<session scratch dir>` in path patterns."),
    # 3.3.3: an overlong code line
    ("constraints[]        {text, source}: an action the delegate is required or forbidden to take (for\n                     example shipping a code change, D-DEL4), and every skill conflict",
     "constraints[]        {text, source}: an action the delegate is required or forbidden to\n                     take (for example shipping a code change, D-DEL4), and every skill conflict"),
    # 3.4.1: 874d-11 RFI 4, settled
    ("Prose MAY precede it.", "Prose MAY precede or follow it."),
    # 3.4.4, 3.4.5: obligations without a key word
    ("- `deliverables` lists what the delegate produced for it (D874d-34).",
     "- `deliverables` MUST list what the delegate produced for it, as deliverable entries (3.2.6; D874d-34)."),
    ("`from.kind` `rule`, reported at once (D-DEL9);",
     "`from.kind` `rule`, reported as 3.2.3 requires (D-DEL9);"),
    ("- PR URLs and files become an objective's `deliverables`.",
     "- a PR URL or a file becomes a deliverable entry of the objective it serves (3.2.6)."),
    # 3.5.3: passive
    ("- The duty is added to the prompt-turn checklist, item 12 (plan batch 2.3).",
     "- Plan batch 2.3 adds this duty to item 12 of the prompt-turn checklist."),
    # 3.6.5: read verbs too (3.6.9)
    ("There is no `--session` argument on the session-DB write verbs (D874d-31, 3.6.9):",
     "There is no `--session` argument on the session-DB verbs (D874d-31, 3.6.9):"),
    # section 4 rows brought in line with v1.4
    ("| S-15 | Removing `--session` | From the session-DB write verbs only, in the same change as the hooks;",
     "| S-15 | Removing `--session` | From the session-DB verbs that 3.6.10 lists, write and read, in the same change as the hooks;"),
    ("rewrites refs; delegates' RFIs are `R<mission name>-<n>` (3.2.4)",
     "rewrites refs; a delegate's RFIs in a document not yet in the DB are `R<mission name>-<n>` (3.2.4)"),
    # section 8
    ("| WP-0 | This RFC and the plan, on main (D874d-59, D874d-69); the four verifiers' findings applied; no separate verdict is kept (D874d-68) |",
     "| WP-0 | This RFC and the plan, on main (D874d-59, D874d-69); the findings of four verifiers (874d-3 to 874d-6) and three language reviewers (874d-7, 874d-9, 874d-11) applied; no separate verdict is kept (D874d-68) |"),
    # section 9
    ("and R874d-40 to R874d-43 on L3479 (D874d-66 to D874d-69).",
     "R874d-40 to R874d-43 on L3479 (D874d-66 to D874d-69), R874d-44 and R874d-45 on L4045 (D874d-71 to D874d-74), and R874d-46 to R874d-48 on L4523 (D874d-75 to D874d-77)."),
    # section 10
    ("`874d-5-brief-verify-aar.json`, `874d-6-standards-verify-aar.json`.",
     "`874d-5-brief-verify-aar.json`, `874d-6-standards-verify-aar.json`; the language reviewers' `874d-7-normative-language-aar.json`, `874d-9-implementer-read-aar.json` and `874d-11-consistency-aar.json`; and `874d-10-consistency-forensics-aar.json`, on why mission 874d-8 stopped."),
]
for i, (old, new) in enumerate(OWN, 1):
    n = text.count(old)
    if n != 1:
        print(f"FAIL own edit {i}: found {n}: {old[:80]!r}", file=sys.stderr)
        sys.exit(1)
    text = text.replace(old, new)
print("phase 2:", len(OWN), "own edits applied")
open(rfc_path, "w", encoding="utf-8").write(text)
