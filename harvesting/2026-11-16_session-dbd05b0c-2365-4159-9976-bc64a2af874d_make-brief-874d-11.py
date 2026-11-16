"""Write the brief of mission 874d-11-consistency (RFC 0011 v1.4, 3.3), the relaunch of 874d-8's lens.

Usage: make-brief-874d-11.py <session scratch dir>
"""
import json
import sys
from collections import OrderedDict
from datetime import datetime, timezone

scratch = sys.argv[1]
SESSION_ID = "dbd05b0c-2365-4159-9976-bc64a2af874d"
HOME = "/Users/new-jose"
AITOOLS = f"{HOME}/repos/aitools"
PROJ = f"{HOME}/.claude/projects/-Users-new-jose-repos-aitools"
TRANSCRIPT = f"{PROJ}/{SESSION_ID}.jsonl"
RFC = f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md"
NAME = "874d-11-consistency"
ORDER = "veerify the language you use and each line in the rfc line by line verbatim against formal best-practices for SWE."
RELAUNCH = "46) yes, relaunch fresh, yes try sonnet 5.5 1M context with high effot"
TASK = ("Review RFC 0011 v1.4 line by line for consistency and formal register: every defined term used with one "
        "meaning and every term used defined; one name per concept (no synonyms); every section, clause, table, "
        "decision id (D874d-<n>, D-DEL<n>) and settled-point id (S-<n>) reference resolves and supports what the "
        "sentence says; tables and prose agree; clause numbering is continuous; identifiers are in code format; "
        "abbreviations are expanded on first use; and the register is formal technical English (no colloquialisms, "
        "contractions, rhetorical phrasing, first person or informal intensifiers). Work in five batches, in this "
        "order: sections 1 and 2; 3.1 and 3.2; 3.3 to 3.5; 3.6 to 3.9; sections 4 to 10 and appendix A. After each "
        "batch, write your AAR file as a new version holding every finding so far. Report each defect with the RFC "
        "line and the exact replacement text.")


def src(kind, location):
    return OrderedDict(kind=kind, location=location)


full = [f"{HOME}/.claude/CLAUDE.md"] + [f"{HOME}/.claude/rules/{n}.md" for n in (
    "delegation", "prompt-turn", "scratch", "tool-evaluation", "tool-lifecycle", "tool-ops", "web-sources")] + [
    f"{AITOOLS}/CLAUDE.md", f"{AITOOLS}/.aitools/channel/CLAUDE.md"] + [f"{AITOOLS}/.claude/rules/{n}.md" for n in (
    "agentic-standards", "aitools-workspace", "config-file-safety", "cross-platform", "deploy-paths",
    "documentation-standards", "frameworks", "git-safety", "glossary", "governed-data-access", "hook-lifecycle",
    "hook-rollout", "incident-governance", "interactive-menus", "managed-file-deployment", "script-standards",
    "smoke-test-pattern")] + [
    f"{HOME}/.claude/skills/delegate/SKILL.md", f"{AITOOLS}/shared/skills/scratch/SKILL.md",
    f"{AITOOLS}/.claude/skills/glossary/SKILL.md", RFC]
ref = [TRANSCRIPT, f"{AITOOLS}/plans/structured-reports/implementation-plan.md", f"{AITOOLS}/rfcs/README.md",
       f"{AITOOLS}/rfcs/RFC-0001-workspace-tool-requests.md",
       f"{AITOOLS}/.scratch/session-874d-8-cns/scan.pl",
       f"{scratch}/874d-7-normative-language-aar.json", f"{scratch}/874d-9-implementer-read-aar.json"]

C = [
    ("Read-only: do not edit, commit or push any repository file, and do not comment on or edit any issue or PR. "
     "Write only in your scratch directory and your AAR file.", "session agent dbd05b0c"),
    ("Review in the five batches of OBJ-2, in order. After each batch, write your AAR file as a new version "
     "(provenance.version v1.0, v1.1, ...) holding every finding so far, before you start the next batch.",
     f"mission 874d-10-consistency-forensics PRO-2 ({scratch}/874d-10-consistency-forensics-aar.json)"),
    ("Do not alter a quotation of the commander: quoted text keeps its spelling, spacing and punctuation. Propose "
     "changes to the RFC's own prose only.", f"{RFC} section 2; D-DEL6"),
    ("Do not reopen the commander's decisions (D874d-<n>); a decision you judge unsound is a proposal, not a defect.",
     f"{RFC}, Status of this memo"),
    ("Do not repeat a defect that RFC 0011 v1.4 already fixes: v1.4 applied the proposals of missions 874d-7 and "
     "874d-9 (their AAR files are reference artifacts). Report only what v1.4 still has.", "session agent dbd05b0c"),
    ("Cite every defect by its RFC line number, as read from disk when you start, and quote the text; every proposal "
     "gives the exact old text and new text, the old text occurring exactly once in the RFC.", "session agent dbd05b0c"),
    ("Fetch issue nobul-tech/aitools#180 yourself (gh issue view 180 --repo nobul-tech/aitools, with and without "
     "--comments; body v5.5 or later); do not use the copies in the 874d-8 scratch directory, which are stale.",
     f"mission 874d-10-consistency-forensics OBS-6 and PRO-4"),
    ("Stop every background shell and monitor you start before you hand back.", f"{HOME}/.claude/skills/delegate/SKILL.md"),
]
brief = OrderedDict(
    provenance=OrderedDict(
        document="mission-brief", schema_version=1, version="v1.0", mission=NAME, session_id=SESSION_ID,
        session_db="", session_scratch=scratch,
        written_by=OrderedDict(agent_id=SESSION_ID, agent_type="session", mission=None),
        chain_of_command=[TRANSCRIPT], created_at=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
    identity=OrderedDict(name=NAME, level=1, delegated_by=f"session agent {SESSION_ID}", parallel_missions=[]),
    intent=OrderedDict(
        purpose="Consistency and formal register: report every defect of RFC 0011 v1.4 in this lens, with its line "
                "and exact replacement text, so the session agent can bring the RFC to formal software-engineering "
                "specification quality; the relaunch of mission 874d-8, which an API safeguard stopped",
        scope=f"{RFC}, every line, in this lens only",
        out_of_scope=["editing any repository file", "the defects missions 874d-7 and 874d-9 reported, which v1.4 applies",
                      "the commander's decisions and quotations", "the plan and the brief"],
        audience="the session agent dbd05b0c, which applies the fixes, and the commander"),
    objectives=[
        OrderedDict(id="OBJ-1", type="objective", text=ORDER, source=src("commander", f"{TRANSCRIPT} L4045"), quote=ORDER),
        OrderedDict(id="OBJ-2", type="objective", text=TASK,
                    source=src("agent", f"session agent {SESSION_ID}, this brief; the relaunch the commander ordered: {TRANSCRIPT} L4523")),
    ],
    constraints=[OrderedDict(text=t, source=src("agent", s)) for t, s in C],
    assumptions=[OrderedDict(
        id="ASM-1", type="assumption",
        text="RFC 0011 does not change on disk while you review it: the session agent waits for you",
        status="unverified", confidence="high", evidence="the session agent's plan for this turn",
        impact_if_false="a line number you cite no longer matches; re-read the file and cite again",
        source=src("agent", f"session agent {SESSION_ID}"))],
    decisions=[OrderedDict(id="D874d-75", type="decision",
                           text="The consistency review is relaunched fresh, on Sonnet with high effort",
                           decided_by="commander", date="2026-11-16", source=src("commander", f"{TRANSCRIPT} L4523"),
                           quote=RELAUNCH, status="decided")],
    operational_learning=[
        OrderedDict(id="OL-1", type="operational_learning",
                    text="Mission 874d-8, given this lens on RFC 0011 v1.3, was stopped by an API safety classifier "
                         "(category reasoning_extraction) during two long turns that held only reasoning, and left no "
                         "findings: write findings to your AAR file after each batch, so a stop loses at most one batch",
                    source=src("telemetry", f"{scratch}/874d-10-consistency-forensics-aar.json OBS-9")),
        OrderedDict(id="OL-2", type="operational_learning",
                    text="874d-8's scan.pl flags candidate register defects per RFC line (contraction, first-person, "
                         "informal, lowercase RFC 2119 keyword, abbreviation, placeholder, synonym) after dropping "
                         "double-quoted text. Re-run it on v1.4: its old scan.log no longer matches the line numbers. "
                         "Its contraction hits are possessives, not contractions",
                    source=src("artifact", f"{scratch}/874d-10-consistency-forensics-aar.json OBS-4, OBS-5")),
        OrderedDict(id="OL-3", type="operational_learning",
                    text="RFC 8174 section 2, read in the browser on 2026-11-16: key words have their RFC 2119 meaning "
                         "\"when, and only when, they appear in all capitals, as shown here\"; RFC 0011 v1.4 adopts "
                         "that phrase in section 2",
                    source=src("telemetry", f"{PROJ}/{SESSION_ID}/subagents/agent-af0c5e479d52a9629.jsonl L135")),
        OrderedDict(id="OL-4", type="operational_learning",
                    text="In zsh an unquoted glob such as grep --include=*.meta.json fails with 'no matches found'. "
                         "Your own agentId: grep -rl \"874d-11-consistency:\" in the parent session's subagents directory",
                    source=src("telemetry", f"{scratch}/874d-10-consistency-forensics-aar.json OL-1")),
        OrderedDict(id="OL-5", type="operational_learning",
                    text="The harvester copies top-level scratch files into the tracked harvesting/ of a public repo: "
                         "save copies of the issue or the transcript under a .tmp name",
                    source=src("artifact", f"{RFC} section 7")),
    ],
    artifacts=[OrderedDict(path=p, instruction="read in full") for p in full] +
              [OrderedDict(path=p, instruction="use as reference for answers") for p in ref],
    deliverables=[OrderedDict(
        kind="aar", ref=f"{scratch}/{NAME}-aar.json", objective="",
        text="your AAR: JSON in the AAR schema of RFC 0011 3.4, the last fenced json block of your final message, "
             "and the same JSON in this file, written as a new version after each batch")],
)
path = f"{scratch}/{NAME}-brief.json"
with open(path, "w", encoding="utf-8") as f:
    json.dump(brief, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(path)
