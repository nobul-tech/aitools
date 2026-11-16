"""Build issue #180 body v5.4 from v5.3: decisions D874d-54 to D874d-70 and the new brief schema.

Usage: issue-v54.py <v5.3 body file> <out body file>
Each exact replacement must match once; the mission-brief span is replaced between two
anchors that must each occur once. On any miss the script exits 1 and writes nothing.
"""
import sys

src, out = sys.argv[1], sys.argv[2]
body = open(src, encoding="utf-8").read()


def once(old: str, new: str) -> None:
    global body
    n = body.count(old)
    if n != 1:
        print(f"FAIL: expected 1 match, found {n}: {old[:80]!r}", file=sys.stderr)
        sys.exit(1)
    body = body.replace(old, new)


T = "Session dbd05b0c"

# 1. Body version.
once(
    "**Body version.** v5.3 (2026-11-16, session dbd05b0c)",
    "**Body version.** v5.4 (2026-11-16, session dbd05b0c), from the commander's prompts of L3394, L3479 and "
    "L3589: decisions D874d-54 to D874d-70 in section 1; in section 3 the brief's `artifacts[]` (D874d-65) and "
    "`deliverables[]` (D874d-70) replace `rules[]`, `skills[]`, `ambiguities`, `access`, `name_prefix`, `duties` "
    "and `return`, items inherit their writer fields (D874d-55), and a decision can be `superseded` (D874d-56). "
    "Sections changed in this version are marked *Changed in v5.4*. Sections 5 and 6 moved, verbatim, to the "
    "comment \"Sections 5 and 6 (moved in v5.4)\", to keep this body under GitHub's size limit.\n\n"
    "v5.3 (2026-11-16, session dbd05b0c)",
)

# 2. How to use: the RFC is now the normative text.
once(
    "The decisions in section 1 are the commander's; the RFC does not reopen them. A point the RFC finds unclear "
    "goes to the commander as an RFI with a suggested answer.",
    "The decisions in section 1 are the commander's; the RFC does not reopen them. A point the RFC finds unclear "
    "goes to the commander as an RFI with a suggested answer.\n\n"
    "*Changed in v5.4:* RFC 0011 v1.2 (`rfcs/RFC-0011-structured-reports.md`, on `main`) is now the normative "
    "text, with its plan `plans/structured-reports/implementation-plan.md` v1.1; WP-0 is done (D874d-59, "
    "D874d-68, D874d-69). Where this body and the RFC differ, the RFC wins, except for the decisions of section 1.",
)

# 3. Decisions table: D874d-30 note, and the new rows.
once(
    "A schema field is adopted only as a governed term; `artifact_refs` is not adopted (replaced by "
    "`deliverables`, D874d-34) |",
    "A schema field is adopted only as a governed term; `artifact_refs` is not adopted (replaced by "
    "`deliverables`, D874d-34). *The glossary requirement is set aside for now by D874d-66* |",
)
NEW_ROWS = [
    ("D874d-54", "The session content already in the public repo (the tracked `.aitools/channel/running-estimate.json`, harvested files) needs no action from this work", "L3394, on R874d-29", "29) dont worry about it"),
    ("D874d-55", "Items in a brief or an AAR inherit `version`, `agent_id`, `agent_type`, `mission` and `created_at` from `provenance`; every DB row carries them (RFC 0011 S-18)", "L3394, on R874d-30", "30) accepted"),
    ("D874d-56", "A decision's status gains `superseded`, with `superseded_by[]` naming the superseding decision and the part (RFC 0011 S-19)", "L3394, on R874d-31", "31)yes"),
    ("D874d-57", "`harness-db.py` keeps no deprecated `--session` alias", "L3394, on R874d-32", "32) no"),
    ("D874d-58", "At session start, the harness adds `.aitools/` and `.scratch/` to `.git/info/exclude` in any repo where nothing ignores them, and reports it once", "L3394, on R874d-33", "33)yes"),
    ("D874d-59", "RFC 0011, its `rfcs/README.md` row and the plan are committed and pushed to `main` now (commit 419d32dd)", "L3394, on R874d-34", "34) commit and push the changes now to the main branch"),
    ("D874d-60", "The implementing mission updates the plan's status table inside each work package's PR, in its worktree", "L3394, on R874d-35", "35) inside each work package's PR (worktree"),
    ("D874d-61", "The dashboards are repointed to the per-session export (WP-5), and `.claude/rules/aitools-workspace.md` is updated (WP-2)", "L3394, on R874d-36", "36) sure"),
    ("D874d-62", "Not every schema field needs a glossary entry. *Superseded by D874d-66*", "L3394, on R874d-37", "37) no"),
    ("D874d-63", "This issue is corrected as body v5.3", "L3394, on R874d-38", "38) yes"),
    ("D874d-64", "Standing duties are documented in `/delegate`, never in the brief", "L3394, on R874d-39", "39) the standing duties should be documented in the skill, not included in the brief."),
    ("D874d-65", "The brief's `rules[]` and `skills[]` become `artifacts[]`: the absolute path of every file the delegate needs, each with an explicit instruction, `read in full` or `use as reference for answers`", "L3394", "the rules[] and skills[] elements in the brief, change that to be an element type artifacts and have that list the absolute path of all files delegates need and there should be explicit instructions to read in full, or to use as reference for answers."),
    ("D874d-66", "The schema's nodes and fields get no glossary entries for now; the glossary requirement of D874d-30 is set aside", "L3479, on R874d-40", "40) no means no,  ignore this entirely for now"),
    ("D874d-67", "`artifacts[]` is a plain node. RFC 0011 and the plan define `artifact` as any file the harness or a mission uses; the glossary is left alone for now", "L3479, on R874d-41", "41) ignore the glossary for now, the rfc/plan should address this, and i like your suggestion"),
    ("D874d-68", "No separate WP-0 verdict is kept; the fixes the verifiers found are made", "L3479, on R874d-42", "42) ignore preserving wp-0;s verdict, just make the fixes/changes that it needs"),
    ("D874d-69", "RFC 0011 v1.2 and plan v1.1 are committed and pushed straight to `main`; the decisions and the new brief schema are recorded in this issue (v5.4)", "L3479, on R874d-43", "43) yes, commit/push directly to main"),
    ("D874d-70", "The brief drops `ambiguities`, `access`, `name_prefix` and `duties`; `return` becomes `deliverables[]`, structured to match the RFC", "L3589", "hey in the brief schema lets get rid of ambiguities, access, name_prefix, duties.   lets also rename return to deliverables[] aand have it be structured and match the RFC.  update all documents"),
]
anchor = '| D874d-53 | The dotprofile\'s directory is `running-estimates/`'
idx = body.find(anchor)
if idx < 0 or body.count(anchor) != 1:
    print("FAIL: D874d-53 row", file=sys.stderr)
    sys.exit(1)
end = body.index("\n", idx)
rows = "".join(
    f'\n| {i} | {d} | 2026-11-16 | commander | {T} {loc}: "{q}" |' for (i, d, loc, q) in NEW_ROWS
)
body = body[:end] + rows + body[end:]

once(
    "The row is marked review-after (D-DEL5).",
    "The row is marked review-after (D-DEL5). The commander then placed the standing duties in the skill, not "
    "the brief (D874d-64).",
)

# 4. Section 2: FACT ids.
once("`ASM`, `OL`, `PRO`; an RFI keeps", "`ASM`, `FACT`, `OL`, `PRO`; an RFI keeps")

# 5. Section 3: the visual.
once(" | ambiguities  already resolved, flagged  |", " | operational_learning  (carried forward) |")
once(" | operational_learning  (carried forward) |        | rfis",
     " | artifacts    read in full, or reference |        | rfis")
once(" | rules, skills, access, name_prefix,     |", " | deliverables  the AAR among them        |")
once(" | duties, return                          |", " |                                         |")

# 6. Section 3: nodes by document.
once("| `ambiguities` | already resolved | found, how resolved | yes |", "| `ambiguities` | | found, how resolved | yes |")
once(
    "| `rules`, `skills`, `access`, `name_prefix`, `duties`, `return` | yes | | |",
    "| `artifacts` | yes (D874d-65) | | |\n"
    "| `deliverables` | yes: what the delegate is to produce (D874d-70) | per objective | per objective |",
)
once(
    "`conflict_priority` and `permissions` (standing duties in `/delegate` and the rule, D-DEL13), `meta` "
    "(D874d-19), `findings` (D874d-22).",
    "`conflict_priority` and `permissions` (standing duties in `/delegate`, D874d-64), `meta` (D874d-19), "
    "`findings` (D874d-22). Not in a brief: `rules` and `skills` (D874d-65); `ambiguities`, `access`, "
    "`name_prefix`, `duties` and `return` (D874d-70). *Changed in v5.4.*",
)

# 7. Section 3: common fields.
once("text           the statement\nagent_id", "text           the statement\nversion        1, then + 1 per later version; the key is (id, version)\nagent_id")
once(
    "severity       critical | high | medium | low        (optional: deviation, observation)\n```\n",
    "severity       critical | high | medium | low        (optional: deviation, observation)\n```\n\n"
    "In a brief or an AAR, an item MAY omit `version`, `agent_id`, `agent_type`, `mission` and `created_at`; it "
    "inherits them from `provenance`. Every DB row carries them (D874d-55). A credential in a quote becomes "
    "`[redacted]` (RFC 0011 S-24). *Changed in v5.4.*\n",
)

# 8. Section 3: objective deliverables, decision status, fact, the deliverable entry.
once(
    "  deliverables[]     what it produced: PR or issue URL, commit SHA, file path (D874d-34)",
    "  deliverables[]     what it produced: deliverable entries (below; D874d-34, D874d-70)",
)
once(
    "  text, decided_by, date, quote,\n  status             decided | implemented | verified | deferred | reversed\n",
    "  text, decided_by, date, quote,\n  status             decided | implemented | verified | deferred | reversed |\n"
    "                     superseded\n"
    "  superseded_by[]    {decision, part}: what supersedes it, and which part (D874d-56); status\n"
    "                     is superseded only when the whole decision is\n",
)
once(
    "  status             open | answered | withdrawn\n```\n",
    "  status             open | answered | withdrawn\n\n"
    "fact  FACT-n         session DB only; no document node lists facts (D874d-32, D874d-43)\n"
    "  text, evidence\n\n"
    "deliverable entry   one shape in a brief's deliverables[] (what to produce) and an\n"
    "                    objective's deliverables[] (what was produced) (D874d-70)\n"
    "  kind              aar | pr | issue | commit | file\n"
    "  ref               a pointer a reader can open: a file's absolute path, a PR or issue URL,\n"
    "                    a commit SHA; in a brief, where it is expected; for the AAR, the AAR\n"
    "                    file's path when one is requested, else empty (the hand-back only)\n"
    "  objective         the OBJ id it serves (in a brief)\n"
    "  text              what it is\n```\n",
)

# 9. Section 3: the mission brief, between two anchors.
start_anchor = "### Mission brief\n"
end_anchor = "**Blockers in the brief:**"
for a in (start_anchor, end_anchor):
    if body.count(a) != 1:
        print(f"FAIL: anchor {a!r} found {body.count(a)} times", file=sys.stderr)
        sys.exit(1)
s, e = body.index(start_anchor), body.index(end_anchor)
BRIEF = """### Mission brief

*Changed in v5.4 (D874d-64, D874d-65, D874d-70); RFC 0011 3.3 is the normative text.* Written by the delegating agent before launch, as a JSON file with one top-level key per node, at `<session scratch dir>/<mission name>-brief.json` (D874d-42, section 2). The delegation prompt gives its path and the instruction "Before any other work, read your mission brief in full, line by line: `<path>`", the objectives verbatim (D-DEL8), any unstructured context (D-DEL12), and what the brief no longer holds (D874d-70): the scratch directory, the paths the delegate may write, the sources that are not files, and the name prefix (D-DEL1).

```
provenance
  document           mission-brief
  schema_version     1
  version            v1.0, v1.1 ... (D-DEL5)
  mission            <commanderid>-<n>-<slug>, the delegate's name
  session_id         the top-level session's id
  session_db         the session DB's path; empty until schema 5
  session_scratch    the top-level session's scratch directory (every brief lives there)
  written_by         {agent_id, agent_type, mission when a delegate delegates}
  chain_of_command[] transcript path of every agent above the delegate
  created_at
identity             name, level, delegated_by, parallel_missions[] {mission, scope}
intent               purpose, scope, out_of_scope[], audience
objectives[]         objective: text verbatim + source                       D-DEL8
constraints[]        what the delegate must do or must not do: text + source; every
                     skill conflict pre-resolved (allowed or overridden)
assumptions[]        what the delegating agent assumes; the delegate verifies or
                     falsifies each
decisions[]          the decisions the delegate must honour, quoted
operational_learning[]  carried forward, each with its source
artifacts[]          every file the delegate needs, by absolute path        D874d-65
  path               the file's absolute path
  instruction        "read in full" | "use as reference for answers"
deliverables[]       what the delegate is to produce, the AAR always among them,
                     as deliverable entries (section 3, "Fields by item type") D874d-70
```

**What goes in `artifacts[]`** (RFC 0011 3.3.3a):
- **`read in full`:** every CLAUDE.md file and rule; the SKILL.md of every skill the mission uses, `/delegate` first; the mission's specifications; every file the delegate changes or verifies.
- **`use as reference for answers`:** the chain-of-command transcripts, read with `read-session.py` or `read-session-full.py`, the commander's prompts newest first, whenever a question comes up; large reports and extracted documents.
- **Never listed:** a governed registry's JSON file (its skill's SKILL.md instead), and anything that is not a file (an issue, a PR, a web page), which the prompt names with the command to read it.

"""
body = body[:s] + BRIEF + body[e:]

with open(out, "w", encoding="utf-8") as f:
    f.write(body)
print("ok:", len(body), "chars")
