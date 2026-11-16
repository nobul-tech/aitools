"""Write the briefs of the three language reviewers of RFC 0011 v1.3 (missions 874d-7 to 874d-9).

Usage: make-briefs-lang.py <session scratch dir>
Briefs follow RFC 0011 v1.3 section 3.3 (ten nodes) and live in the session scratch directory
(the default location, D874d-73).
"""
import json
import sys
from collections import OrderedDict
from datetime import datetime, timezone

scratch = sys.argv[1]
SESSION_ID = "dbd05b0c-2365-4159-9976-bc64a2af874d"
HOME = "/Users/new-jose"
AITOOLS = f"{HOME}/repos/aitools"
TRANSCRIPT = f"{HOME}/.claude/projects/-Users-new-jose-repos-aitools/{SESSION_ID}.jsonl"
RFC = f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md"
CREATED = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
L4045 = f"{TRANSCRIPT} L4045"


def src(kind, location):
    return OrderedDict(kind=kind, location=location)


ORDER = "veerify the language you use and each line in the rfc line by line verbatim against formal best-practices for SWE."
LENSES = [
    ("874d-7-normative-language", "Normative language and requirement quality",
     "Review RFC 0011 v1.3 line by line for normative language and requirement quality: RFC 2119 as clarified by "
     "RFC 8174 (keywords in uppercase only where normative; a lowercase must, should or may in a normative clause "
     "is ambiguous); every MUST and MUST NOT names its actor and can be verified by a test or an inspection; every "
     "SHOULD says or implies when departing from it is acceptable; every requirement is singular (one obligation), "
     "unambiguous and free of vague terms (for example short, large, well within); passive voice that hides who "
     "acts; and the requirement characteristics of ISO/IEC/IEEE 29148 (necessary, unambiguous, complete, singular, "
     "feasible, verifiable, correct, consistent). Report each defect with the RFC line and the exact replacement text."),
    ("874d-8-consistency", "Consistency and formal register",
     "Review RFC 0011 v1.3 line by line for consistency and formal register: every defined term used with one "
     "meaning and every term used defined; one name per concept (no synonyms); every section, clause, table, "
     "decision id (D874d-<n>, D-DEL<n>) and settled-point id (S-<n>) reference resolves and supports what the "
     "sentence says; tables and prose agree; clause numbering is continuous; identifiers are in code format; "
     "abbreviations are expanded on first use; and the register is formal technical English (no colloquialisms, "
     "contractions, rhetorical phrasing, first person or informal intensifiers). Report each defect with the RFC "
     "line and the exact replacement text."),
    ("874d-9-implementer-read", "Adversarial implementer's reading",
     "Read RFC 0011 v1.3 line by line as an implementer with no other context who must build and test it: find "
     "every sentence that two competent implementers would implement differently; every requirement that lacks a "
     "precondition, an error behaviour, a boundary case or an order of operations it depends on; every term an "
     "implementer cannot resolve from the RFC and the files it cites; and every pair of statements that contradict "
     "each other. Report each defect with the RFC line, the two readings or the gap, and the exact replacement text."),
]
SCRATCH_SHORT = {"874d-7-normative-language": "874d-7-nrm", "874d-8-consistency": "874d-8-cns",
                 "874d-9-implementer-read": "874d-9-imp"}

DECISIONS = [
    ("D874d-71", "Only the implementing mission's brief (874d-2) moves to the briefs directory", "44) just this one"),
    ("D874d-72", "The briefs directory is tracked in git, as plans are", "45) add briefs to git, plans too."),
    ("D874d-73", "A brief resides in the session scratch directory by default; it resides in the briefs directory only on the commander's order",
     "briefs should live in scratch by default because most of othem are ephemeral, but if i order them to live in briefs they can live there."),
    ("D874d-74", "The briefs directory is where briefs with a long lifecycle, like roadmap items, reside",
     "document the locatino of briefs/ as a location where briefs that have a long lifecycle need to live, like roadmap items."),
]

full = [f"{HOME}/.claude/CLAUDE.md"] + [f"{HOME}/.claude/rules/{n}.md" for n in (
    "delegation", "prompt-turn", "scratch", "tool-evaluation", "tool-lifecycle", "tool-ops", "web-sources")] + [
    f"{AITOOLS}/CLAUDE.md"] + [f"{AITOOLS}/.claude/rules/{n}.md" for n in (
    "documentation-standards", "glossary", "governed-data-access", "frameworks", "cross-platform", "hook-rollout",
    "aitools-workspace")] + [
    f"{HOME}/.claude/skills/delegate/SKILL.md", f"{AITOOLS}/shared/skills/scratch/SKILL.md",
    f"{AITOOLS}/shared/skills/intent-writing/SKILL.md", RFC]
ref = [TRANSCRIPT, f"{AITOOLS}/plans/structured-reports/implementation-plan.md", f"{AITOOLS}/rfcs/README.md",
       f"{AITOOLS}/rfcs/RFC-0001-workspace-tool-requests.md", f"{AITOOLS}/rfcs/0010-python-sqlite-engineering.md",
       f"{AITOOLS}/shared/rules/delegation.md", f"{AITOOLS}/briefs/874d-2-structured-reports-brief.json"]

C = [
    ("Read-only: do not edit, commit or push any repository file, and do not comment on or edit any issue or PR. "
     "Write only in your scratch directory and your AAR file.", "session agent dbd05b0c"),
    ("Do not alter a quotation of the commander: quoted text keeps its spelling, spacing and punctuation. Propose "
     "changes to the RFC's own prose only.", f"{RFC} section 2; D-DEL6"),
    ("Do not reopen the commander's decisions (D874d-<n>); a decision you judge unsound is a proposal, not a defect.",
     f"{RFC}, Status of this memo"),
    ("Cite every defect by its RFC line number, as read from disk when you start, and quote the text. Every proposal "
     "gives the exact old text and new text.", "session agent dbd05b0c"),
    ("When you cite a standard's wording (RFC 2119, RFC 8174, RFC 7322, ISO/IEC/IEEE 29148), read it in the browser "
     "through the chrome-devtools skill; if the browser is unavailable, use WebFetch and say so. Say unknown rather "
     "than quote from memory.", f"{HOME}/.claude/rules/web-sources.md"),
    ("Stop every background shell and monitor you start before you hand back.", f"{HOME}/.claude/skills/delegate/SKILL.md"),
]

for name, title, task in LENSES:
    others = [OrderedDict(mission=n, scope=t) for (n, t, _) in LENSES if n != name]
    aar_path = f"{scratch}/{name}-aar.json"
    brief = OrderedDict(
        provenance=OrderedDict(
            document="mission-brief", schema_version=1, version="v1.0", mission=name, session_id=SESSION_ID,
            session_db="", session_scratch=scratch,
            written_by=OrderedDict(agent_id=SESSION_ID, agent_type="session", mission=None),
            chain_of_command=[TRANSCRIPT], created_at=CREATED),
        identity=OrderedDict(name=name, level=1, delegated_by=f"session agent {SESSION_ID}", parallel_missions=others),
        intent=OrderedDict(
            purpose=f"{title}: report every defect of RFC 0011 v1.3 in this lens, with its line and exact replacement "
                    "text, so the session agent can bring the RFC to formal software-engineering specification quality",
            scope=f"{RFC}, every line, in this lens only",
            out_of_scope=["editing any repository file", "the other two reviewers' lenses",
                          "the commander's decisions and quotations", "the plan and the brief"],
            audience="the session agent dbd05b0c, which applies the fixes, and the commander"),
        objectives=[
            OrderedDict(id="OBJ-1", type="objective", text=ORDER, source=src("commander", L4045), quote=ORDER),
            OrderedDict(id="OBJ-2", type="objective", text=task, source=src("agent", f"session agent {SESSION_ID}, this brief")),
        ],
        constraints=[OrderedDict(text=t, source=src("agent", s)) for t, s in C],
        assumptions=[OrderedDict(
            id="ASM-1", type="assumption",
            text="RFC 0011 does not change on disk while you review it: the session agent waits for the three reviewers",
            status="unverified", confidence="high", evidence="the session agent's plan for this turn",
            impact_if_false="a line number you cite no longer matches; re-read the file and cite again",
            source=src("agent", f"session agent {SESSION_ID}"))],
        decisions=[OrderedDict(id=i, type="decision", text=t, decided_by="commander", date="2026-11-16",
                               source=src("commander", L4045), quote=q, status="decided") for i, t, q in DECISIONS],
        operational_learning=[
            OrderedDict(id="OL-1", type="operational_learning",
                        text="A sub-agent's Write is refused for a Markdown file whose name starts with REPORT, SUMMARY, "
                             "FINDINGS or ANALYSIS; the mission-name prefix avoids it",
                        source=src("artifact", f"{HOME}/.claude/skills/delegate/SKILL.md 'Environment limits'")),
            OrderedDict(id="OL-2", type="operational_learning",
                        text="Your own agentId is in <parent session dir>/subagents/agent-<agentId>.meta.json, whose "
                             "description starts with your mission name; it exists while you run",
                        source=src("telemetry", f"{HOME}/.claude/projects/-Users-new-jose-repos-aitools/{SESSION_ID}/subagents/")),
            OrderedDict(id="OL-3", type="operational_learning",
                        text="The harvester copies top-level scratch files into the tracked harvesting/ of a public "
                             "repo; save copies of transcripts, prompts or issue bodies under a .tmp name",
                        source=src("artifact", f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md section 7")),
            OrderedDict(id="OL-4", type="operational_learning",
                        text="A message the commander sends while a turn runs is a queue-operation record in the "
                             "transcript, with a content field, not a user record",
                        source=src("telemetry", f"{TRANSCRIPT} L3589")),
        ],
        artifacts=[OrderedDict(path=p, instruction="read in full") for p in full] +
                  [OrderedDict(path=p, instruction="use as reference for answers") for p in ref],
        deliverables=[OrderedDict(
            kind="aar", ref=aar_path, objective="OBJ-2",
            text="your AAR: JSON in the AAR schema of RFC 0011 3.4, the last fenced json block of your final message, "
                 "and the same JSON in this file (requested)")],
    )
    path = f"{scratch}/{name}-brief.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(brief, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(path, "| scratch:", f"{AITOOLS}/.scratch/session-{SCRATCH_SHORT[name]}/")
