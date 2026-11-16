"""Write the mission briefs of session dbd05b0c in the RFC 0011 section 3.3 format.

Usage: make-briefs.py <published issue body.md> <session scratch dir>

The decision items are copied from the issue body's decision table (verbatim, already
verified against the transcript), so no quote is retyped. Writes one
<mission name>-brief.json per mission into the session scratch dir and prints each path.
"""
import json
import re
import sys
from collections import OrderedDict

body_path, scratch = sys.argv[1], sys.argv[2]
body = open(body_path, encoding="utf-8").read()

SESSION_ID = "dbd05b0c-2365-4159-9976-bc64a2af874d"
TRANSCRIPT = f"/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/{SESSION_ID}.jsonl"
AITOOLS = "/Users/new-jose/repos/aitools"
from datetime import datetime, timezone

CREATED = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# ---- decisions, parsed from the issue's decision table -------------------------------
decisions = {}
for row in body.splitlines():
    m = re.match(r"^\| (D874d-\d+) \| (.*?) \| (\d{4}-\d{2}-\d{2}) \| (.*?) \| (.*) \|$", row)
    if not m:
        continue
    did, text, date, by, source = m.groups()
    # A trailing parenthetical after the quote (D874d-23) is a note, not part of the quote.
    core = re.sub(r'\s*\([^()]*\)\s*$', "", source) if source.endswith(")") else source
    # The quote is the session dbd05b0c one when the row has it (L<n>[, on R...]: "..."),
    # else the row's single quote.
    q = re.search(r'L\d+(?:, on [^:]+)?: "(.*)"$', core) or re.search(r': "(.*)"$', core)
    quote = q.group(1) if q else ""
    quote = quote.replace('" and "', " … ")
    decisions[did] = OrderedDict(
        id=did, type="decision", text=text, decided_by=by, date=date,
        # The full source column, verbatim: where a row cites two sessions, both stay visible.
        source=OrderedDict(kind="commander" if by == "commander" else "agent",
                           location=source + " (issue #180 v5.2, section 1)"),
        quote=quote, status="decided",
    )

USER_RULES = [f"/Users/new-jose/.claude/CLAUDE.md"] + [
    f"/Users/new-jose/.claude/rules/{n}.md"
    for n in ("delegation", "prompt-turn", "scratch", "tool-evaluation", "tool-lifecycle", "tool-ops", "web-sources")
]
PROJECT_RULES = [f"{AITOOLS}/CLAUDE.md", f"{AITOOLS}/.aitools/channel/CLAUDE.md"] + [
    f"{AITOOLS}/.claude/rules/{n}.md"
    for n in ("agentic-standards", "aitools-workspace", "config-file-safety", "cross-platform", "deploy-paths",
              "documentation-standards", "frameworks", "git-safety", "glossary", "governed-data-access",
              "hook-lifecycle", "hook-rollout", "incident-governance", "interactive-menus",
              "managed-file-deployment", "script-standards", "smoke-test-pattern")
]
MISSION_REFS = [
    f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md",
    f"{AITOOLS}/plans/structured-reports/implementation-plan.md",
    f"{AITOOLS}/shared/rules/delegation.md",
    f"{AITOOLS}/shared/skills/delegate/SKILL.md",
    f"{AITOOLS}/reference/framework-intelligence-types.md",
]

OL = [
    ("The deployed /delegate (~/.claude/skills/delegate/SKILL.md) may be older than the aitools working copy "
     "(shared/skills/delegate/SKILL.md v2.6), and issue #180 v5.2 is newer than both; where they differ, "
     "follow the newest words of the commander (D-DEL6), which are in the issue",
     "session dbd05b0c, 2026-11-15/16"),
    ("A delegate's subagents/agent-<agentId>.meta.json (which links its mission name to its agentId) was created "
     "when the delegate finished (20:55:18Z), not at launch; do not rely on it while a delegate runs",
     "session dbd05b0c, mission 874d-1-aar-doctrine"),
    ("ait-harvest.py archive already copies transcripts into the dotprofile and commits and pushes them, "
     "detached because Claude Code gives SessionEnd hooks a short window; session-catchup.sh recovers what an "
     "abrupt exit cut off. Reuse it for the running-estimate copy",
     "shared/hooks/session-archive.sh header; scripts/ait-harvest.py"),
    ("Another session can edit the same working-copy files at the same time (commit 3893c908 staged only its own "
     "lines with git update-index); run git log and git diff on a shared file before editing it",
     "session dbd05b0c, 2026-11-15"),
    ("The 10-character session id prefix includes the UUID's first hyphen (dbd05b0c-2.db)",
     "scripts/harness-db.py session_prefix; D874d-48"),
    ("The harvester copies every non-ephemeral top-level file of a session scratch directory into the tracked "
     "harvesting/; *.json files are ephemeral only when named package-lock*, node_modules*, tsconfig* or "
     "*.config.json, so briefs are harvested until RFC 0011 S-14 ships",
     "scripts/ait-harvest.py _is_ephemeral; shared/skills/scratch/SKILL.md"),
]


def ol_items(prefix_n=1):
    return [OrderedDict(id=f"OL-{i}", type="operational_learning", text=t,
                        source=OrderedDict(kind="agent", location=s))
            for i, (t, s) in enumerate(OL, prefix_n)]


def provenance(mission):
    return OrderedDict(
        document="mission-brief", schema_version=1, version="v1.0", mission=mission,
        session_id=SESSION_ID, session_db="",
        session_scratch=scratch,
        written_by=OrderedDict(agent_id=SESSION_ID, agent_type="session", mission=None),
        chain_of_command=[TRANSCRIPT], created_at=CREATED,
    )


def skills(extra):
    base = [OrderedDict(name="/delegate", use="load at start, before any other work (D-DEL13); before any delegate of your own, write its brief and prompt per RFC 0011 3.3", override="where the deployed copy and RFC 0011 differ, RFC 0011 and issue #180 win (D-DEL6)"),
            OrderedDict(name="/scratch", use="your scratch directory and file naming", override="")]
    return base + extra


def brief(mission, identity, intent, objectives, constraints, assumptions, decision_ids, ambiguities,
          rules, skill_list, access, duties, ret):
    return OrderedDict(
        provenance=provenance(mission),
        identity=identity,
        intent=intent,
        objectives=objectives,
        constraints=constraints,
        assumptions=assumptions,
        decisions=[decisions[d] for d in decision_ids],
        ambiguities=ambiguities,
        operational_learning=ol_items(),
        rules=rules,
        skills=skill_list,
        access=access,
        name_prefix=f"{mission}-",
        duties=duties,
        **{"return": ret},
    )


def c(text, location):
    return OrderedDict(text=text, source=OrderedDict(kind="agent", location=location))


AAR_RETURN = OrderedDict(
    hand_back="your AAR: JSON in the AAR schema of RFC 0011 section 3.4, in one fenced block (D874d-50, D874d-47)",
    file=None,
)

# ---- 874d-2-structured-reports: the implementing mission -----------------------------
impl = "874d-2-structured-reports"
impl_obj = [
    OrderedDict(id="OBJ-1", type="objective", text="implement structured running estimates, briefings, aars",
                source=OrderedDict(kind="commander", location="issue nobul-tech/aitools#180, Objective (session 87795dc3)"),
                quote="implement structured running estimates, briefings, aars"),
]
for i, (wp, title) in enumerate([
    ("WP-1", "WP-1: reference, schemas, templates, validation"),
    ("WP-2", "WP-2: the harness text, in line with RFC 0011 (D874d-49)"),
    ("WP-3", "WP-3: session DB, schema 5 (RFC 0011 section 3.6)"),
    ("WP-4", "WP-4: hooks and the dotprofile copy (RFC 0011 3.3.5, 3.4, 3.5.5, section 7)"),
    ("WP-5", "WP-5: the skills that use the documents"),
    ("WP-6", "WP-6: release"),
], 2):
    impl_obj.append(OrderedDict(id=f"OBJ-{i}", type="objective", text=title,
                                source=OrderedDict(kind="artifact", location=f"{AITOOLS}/plans/structured-reports/implementation-plan.md, section \"{title}\"")))

ASM = [
    ("ASM-1", "A running delegate can learn its own agentId (D874d-33)", "unverified", "moderate",
     "/delegate 'Claude Code specifics' documents a TaskStop error and the parent transcript", "its rows carry no agent_id; the session agent fills it from the AAR (RFC 0011 3.4.9)"),
    ("ASM-2", "SQLite in WAL mode with a 5-second busy timeout takes several parallel writers without errors", "unverified", "moderate",
     "scripts/harness-db.py connection settings; no load test", "'database is locked'; the CLI retries (RFC 0011 3.6.6)"),
    ("ASM-3", "Every delegate can write the session DB in the main checkout", "unverified", "low",
     "/delegate 'Environment limits': worktree isolation confines writes to the worktree", "the session agent records the delegate's items from its AAR (RFC 0011 3.4.8)"),
    ("ASM-4", "A delegating agent at level 2 or deeper can write briefs into the top-level session's scratch directory", "unverified", "low",
     "same isolation limit", "the brief goes in the delegating agent's own scratch (RFC 0011 3.3.8)"),
    ("ASM-5", "The session agent knows its session id and DB path from the start", "verified", "high",
     "the SessionStart hook prints 'Session started: <id>' and 'Session DB: <path>'", ""),
    ("ASM-6", "The first 10 characters of a session id are unique within one repo", "verified", "high",
     "36 bits", "two sessions would share a DB; checked at session start (RFC 0011 3.6.2)"),
    ("ASM-8", "The six working-copy files of session dbd05b0c reach origin/main before WP-1 starts", "unverified", "moderate",
     "the commander takes care of it (R874d-27: 'dont worry about it')", "gate G1 of the plan stays closed"),
]
impl_asm = [OrderedDict(id=i, type="assumption", text=t, status=s, confidence=cf, evidence=e,
                        impact_if_false=f, source=OrderedDict(kind="agent", location="issue #180 v5.2, section 6"))
            for (i, t, s, cf, e, f) in ASM]

impl_amb = [OrderedDict(id=i, type="ambiguity", text=t, source=OrderedDict(kind="agent", location=loc),
                        readings=r, resolution=res, resolved_by=by, evidence=ev, status="resolved")
            for (i, t, loc, r, res, by, ev) in [
    ("AMB-1", "keep the AAR as a handback", "D874d-47", ["JSON", "Markdown with one heading per node"],
     "JSON in one fenced block", "rfi", "D874d-50"),
    ("AMB-2", "for either we need schema and template/defined structure", "D874d-7", ["reference/", "registries/ behind a skill", "the harness-db.py source"],
     "reference/schemas/ and reference/templates/", "reason", "RFC 0011 S-1"),
    ("AMB-3", "assessment ... updated every turn", "issue #180 section 3", ["the session agent each turn", "a hook", "on hand-back"],
     "the session agent at each prompt turn and after each hand-back; the SessionEnd hook exports", "reason", "RFC 0011 S-2"),
    ("AMB-5", "workflow agent() delegates", "issue #180 section 6", ["a brief per agent() call", "no brief"],
     "a brief per agent() call", "reason", "RFC 0011 S-3"),
    ("AMB-7", "provenance is eternal, against changing an item's status", "issue #180 section 6", ["update in place", "append a version"],
     "append a version", "reason", "RFC 0011 S-4"),
    ("AMB-8", "type-specific fields", "issue #180 section 6", ["one JSON fields column", "one column per field"],
     "one fields column of JSON text, parsed in Python", "reason", "RFC 0011 S-5"),
    ("AMB-10", "a directory called \"running estimates\"", "D874d-52", ["a name with a space", "running-estimates/"],
     "running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json", "rfi", "D874d-53"),
]]

impl_constraints = [
    c("Ship under D-DEL4 as the plan's section 'How every batch is shipped' says: your own worktree off origin/main, one PR per work package based on main, an independent reviewer's verdict before merge; never push to main, force-push, or merge or approve your own PR",
      "shared/rules/delegation.md D-DEL4; the plan"),
    c("Do not reopen the decisions of issue #180 section 1; a point you find unclear goes to the commander as an RFI with a suggested answer",
      "RFC 0011, Status of this memo"),
    c("Python is standard library only, version 3.8 or later",
      "rfcs/0010-python-sqlite-engineering.md sections 2 and 11"),
    c("A new or widened hook check starts in observe mode",
      ".claude/rules/hook-rollout.md"),
    c("Never run aitools, aitools install, setup-user-*, deploy-harness or scripts/build-deploy.sh against the real HOME; tests use an isolated HOME and a copy of the dotprofile",
      "/delegate 'In the aitools repo'"),
    c("Never commit a brief, an AAR, a running-estimate export or the commander's words to a project repo; the record goes to the dotprofile only",
      "RFC 0011 section 7; D874d-52"),
    c("Out of scope: the /debrief, /brief and /channel skills; sharing estimates across sessions; distributed sessions",
      "D874d-11, D874d-9, D874d-10"),
]

impl_brief = brief(
    impl,
    OrderedDict(name=impl, level=1, delegated_by=f"session agent {SESSION_ID}", parallel_missions=[]),
    OrderedDict(
        purpose="Implement RFC 0011 (structured running estimates, mission briefs and AARs) through work packages WP-1 to WP-6 of the plan, shipping each as its own PR",
        scope="WP-1 to WP-6 of plans/structured-reports/implementation-plan.md, batch by batch, each verified as the plan says",
        out_of_scope=["changing the decisions of issue #180", "the /debrief, /brief and /channel skills", "cross-session estimates", "WP-0 (RFC 0011 and the plan, done by session dbd05b0c)"],
        audience="the commander, reviewing each PR; every agent that will write or read briefs, AARs and running estimates",
    ),
    impl_obj, impl_constraints, impl_asm,
    ["D874d-1", "D874d-5", "D874d-7", "D874d-8", "D874d-9", "D874d-13", "D874d-14", "D874d-15", "D874d-17",
     "D874d-19", "D874d-20", "D874d-21", "D874d-22", "D874d-23", "D874d-24", "D874d-25", "D874d-26", "D874d-27",
     "D874d-28", "D874d-29", "D874d-30", "D874d-31", "D874d-32", "D874d-33", "D874d-34", "D874d-35", "D874d-37",
     "D874d-41", "D874d-42", "D874d-43", "D874d-44", "D874d-47", "D874d-48", "D874d-49", "D874d-50", "D874d-51",
     "D874d-52", "D874d-53"],
    impl_amb,
    USER_RULES + PROJECT_RULES + MISSION_REFS + [
        f"{AITOOLS}/rfcs/0005-v2-session-intelligence-architecture.md",
        f"{AITOOLS}/rfcs/0006-delegation-architecture.md",
        f"{AITOOLS}/rfcs/0010-python-sqlite-engineering.md",
        f"{AITOOLS}/reference/framework-mission-command.md",
    ],
    skills([
        OrderedDict(name="/glossary", use="every governed-term change (WP-2)", override=""),
        OrderedDict(name="/intent-writing", use="intent statements of new reference files", override=""),
        OrderedDict(name="/intent-audit", use="verify reference/structured-reports.md (WP-1)", override=""),
        OrderedDict(name="/tool-eval", use="before adding any tool or package (none is planned)", override=""),
    ]),
    OrderedDict(
        read_only=[f"{AITOOLS} (the main checkout)", "/Users/new-jose/repos/aitools-nobul-jose (the dotprofile: never written; tests use a copy)",
                   "/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/ (transcripts)", "issue nobul-tech/aitools#180 (gh issue view 180 --repo nobul-tech/aitools)"],
        writable=[f"{AITOOLS}/.scratch/worktrees/{impl} (your worktree)", "your branches and PRs on nobul-tech/aitools"],
        scratch=f"{AITOOLS}/.scratch/worktrees/{impl}/.scratch/session-874d-2-str",
    ),
    [
        "ship every work package as its own PR, with its tests, CI passing on macOS, Linux and Windows (D-DEL4)",
        "launch an independent reviewer for every PR before merge; its verdict is a PR comment",
        "commit and push after every batch",
        "record the probes of batch 3.5 (ASM-1, ASM-3) in the PR body",
        "update the plan's status table after every batch",
        "add a release-note entry (WP-6)",
    ],
    AAR_RETURN,
)

# ---- the verifiers --------------------------------------------------------------------
VERIFY_QUOTE = "launch delegates to run different types of verfiers including adverserial"
TARGETS = [
    f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md",
    f"{AITOOLS}/plans/structured-reports/implementation-plan.md",
    f"{scratch}/874d-2-structured-reports-brief.json",
]
VERIFIERS = [
    ("874d-3-spec-verify", "874d-3-spc", "Traceability verifier",
     "Trace every decision of issue #180 (body v5.2, D874d-1 to D874d-53) and every point the issue left to the RFC into RFC 0011, the plan and the implementing brief: for each, say where it is carried and whether faithfully, newest decision winning; list every contradiction, omission and misstatement; check that every quote in the brief is verbatim against the session transcript or the issue.",
     "Traceability and spec conformance against issue #180"),
    ("874d-4-adversarial", "874d-4-adv", "Adversarial verifier",
     "Attack RFC 0011, the plan and the implementing brief as an opponent would: run a pre-mortem (assume the implementation failed in use and list why), argue the strongest case for the rejected option of every point the RFC settles itself (section 4), and find what is wrong, missing, ambiguous or unsafe: concurrency and locking, worktree isolation, SessionEnd timing, cross-platform, security and privacy (the aitools repo is open-source), migration and data loss, and every sentence an implementer could read two ways.",
     "Adversarial review: red team and pre-mortem"),
    ("874d-5-brief-verify", "874d-5-brf", "Brief and schema verifier",
     "Verify the implementing brief 874d-2-structured-reports-brief.json against the brief schema of RFC 0011 section 3.3 and issue #180 section 3: valid JSON; top-level keys and their order; required fields and enum values of every item; no forbidden node; objectives verbatim with sources; every quote verbatim against the session transcript or the issue; every path in rules[] and access exists; name and location follow D874d-42; and whether a delegate with no other context could start WP-1 from it.",
     "Brief conformance and sufficiency"),
    ("874d-6-standards-verify", "874d-6-std", "Repo-standards and fact verifier",
     "Verify RFC 0011 and the plan against the aitools repo's standards and facts: the RFC format (rfcs/README.md, RFC 2119), intent statements (/intent-writing), plan conventions (small batches, a verification per batch), the cross-platform, hook-rollout, script and Python standards (RFC 0010), governed vocabulary (/glossary), and that every file path, line number, function name, command and decision ID the documents cite exists as cited.",
     "Repo standards and fact check"),
]

out = [(impl, impl_brief)]
for name, short, role, task, title in VERIFIERS:
    others = [OrderedDict(mission=n, scope=t) for (n, _, _, _, t) in VERIFIERS if n != name]
    obj = [
        OrderedDict(id="OBJ-1", type="objective", text=VERIFY_QUOTE,
                    source=OrderedDict(kind="commander", location=f"session dbd05b0c, transcript L2553 ({TRANSCRIPT})"),
                    quote=VERIFY_QUOTE),
        OrderedDict(id="OBJ-2", type="objective", text=task,
                    source=OrderedDict(kind="agent", location=f"session agent {SESSION_ID}, this brief")),
    ]
    b = brief(
        name,
        OrderedDict(name=name, level=1, delegated_by=f"session agent {SESSION_ID}", parallel_missions=others),
        OrderedDict(
            purpose=f"{role}: {title} of RFC 0011, its implementation plan and the implementing mission's brief, so the session agent can fix them before the commander reviews them",
            scope="the three target files, read against issue #180 v5.2 and the aitools repo",
            out_of_scope=["changing any file other than your own scratch and AAR file", "the other verifiers' scopes", "implementing anything"],
            audience="the session agent dbd05b0c, which applies the fixes, and the commander",
        ),
        obj,
        [c("Read-only: do not edit, commit or push any repo file, and do not comment on or edit any issue or PR; write only in your scratch directory and your AAR file",
           "session agent dbd05b0c"),
         c("Do not reopen the commander's decisions (issue #180 section 1); a decision you think is wrong is a proposal, not a defect",
           "RFC 0011, Status of this memo"),
         c("Every defect cites the exact file and line, and the source it contradicts", "session agent dbd05b0c")],
        [OrderedDict(id="ASM-1", type="assumption", text="The target files are the version written by session dbd05b0c at 2026-11-16 and are not changed while you verify",
                     status="unverified", confidence="high", evidence="the session agent waits for the verifiers before editing them",
                     impact_if_false="re-read a file whose content no longer matches a line you cite", source=OrderedDict(kind="agent", location="session agent dbd05b0c"))],
        ["D874d-31", "D874d-32", "D874d-33", "D874d-35", "D874d-41", "D874d-42", "D874d-47", "D874d-50", "D874d-52", "D874d-53"],
        [],
        USER_RULES + PROJECT_RULES + TARGETS + MISSION_REFS[2:] + [f"{AITOOLS}/rfcs/README.md", f"{AITOOLS}/rfcs/0010-python-sqlite-engineering.md"],
        skills([OrderedDict(name="/glossary", use="check governed terms", override="read only; add no term")]),
        OrderedDict(
            read_only=[f"{AITOOLS} (the main checkout)", TRANSCRIPT + " (search it; never load it whole)",
                       "issue nobul-tech/aitools#180 (gh issue view 180 --repo nobul-tech/aitools --comments, and without --comments for the body)"],
            writable=[f"{AITOOLS}/.scratch/session-{short}/", f"{scratch}/{name}-aar.json"],
            scratch=f"{AITOOLS}/.scratch/session-{short}/",
        ),
        ["write your AAR to the file in access.writable as well as handing it back (an AAR file is requested, D874d-47)"],
        OrderedDict(hand_back=AAR_RETURN["hand_back"], file=f"{scratch}/{name}-aar.json"),
    )
    out.append((name, b))

for name, b in out:
    path = f"{scratch}/{name}-brief.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(b, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(path, len(b["decisions"]), "decisions")
missing = [d for d in ("D874d-31", "D874d-53") if d not in decisions]
print("decisions parsed:", len(decisions), "missing:", missing)
