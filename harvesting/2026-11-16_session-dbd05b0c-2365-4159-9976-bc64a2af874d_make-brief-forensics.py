"""Write the brief of mission 874d-10-consistency-forensics (RFC 0011 v1.3, 3.3).

Usage: make-brief-forensics.py <session scratch dir>
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
FAILED = "af0c5e479d52a9629"
FAILED_T = f"{PROJ}/{SESSION_ID}/subagents/agent-{FAILED}.jsonl"
NAME = "874d-10-consistency-forensics"
ORDER = ("can you launch a mission to look at the transcript of 874d-8-consistency and figure out what happened and "
         "if it produced any work product we can use?")


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
    f"{scratch}/874d-8-consistency-brief.json",
    f"{PROJ}/{SESSION_ID}/subagents/agent-{FAILED}.meta.json"]
ref = [FAILED_T, TRANSCRIPT, f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md",
       f"{AITOOLS}/.scratch/session-874d-8-cns/scan.pl", f"{AITOOLS}/.scratch/session-874d-8-cns/scan.log",
       f"{HOME}/.aitools/bin/read-session.py", f"{HOME}/.aitools/bin/read-session-full.py"]

C = [
    ("Read-only everywhere except your scratch directory and your AAR file: change no repository file, no other "
     "mission's scratch, and no transcript.", "session agent dbd05b0c"),
    ("Do not do 874d-8-consistency's work: do not review RFC 0011 yourself and do not continue its review. Report "
     "what it did and what it left.", "session agent dbd05b0c; the harness note on the failed delegate"),
    ("Do not read, print or quote the thinking blocks of the failed transcript, and do not try to reproduce or "
     "reconstruct the request the safeguard flagged (its detail was [reasoning_extraction]). Work only from its "
     "tool calls, tool results, visible text, the files it wrote and the record metadata (types, timestamps, "
     "sizes). Write a script that skips records or content parts of type thinking.",
     "the failure notice of 874d-8 (request req_011Ch5mefJ6kSLRCLQhLBckr)"),
    ("Never load a transcript whole: read it with a short script in your scratch directory, or with the harness "
     "readers using --no-thinking.", f"{HOME}/.claude/skills/delegate/SKILL.md 'Reading the commander's sessions'"),
    ("Every claim cites its source: a transcript line number, a file path and line, or a command and its output. "
     "Say unknown rather than guess.", f"{HOME}/.claude/CLAUDE.md"),
    ("Stop every background shell and monitor you start before you hand back.", f"{HOME}/.claude/skills/delegate/SKILL.md"),
]
brief = OrderedDict(
    provenance=OrderedDict(
        document="mission-brief", schema_version=1, version="v1.0", mission=NAME, session_id=SESSION_ID,
        session_db="", session_scratch=scratch,
        written_by=OrderedDict(agent_id=SESSION_ID, agent_type="session", mission=None),
        chain_of_command=[TRANSCRIPT], created_at=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
    identity=OrderedDict(name=NAME, level=1, delegated_by=f"session agent {SESSION_ID}", parallel_missions=[
        OrderedDict(mission="874d-7-normative-language", scope="review of RFC 0011 v1.3 (running; do not touch)"),
        OrderedDict(mission="874d-9-implementer-read", scope="review of RFC 0011 v1.3 (running; do not touch)")]),
    intent=OrderedDict(
        purpose="Establish what happened to mission 874d-8-consistency, which an API safeguard stopped, and list any "
                "work product it left that the session agent can use, so the commander can decide whether to "
                "relaunch it",
        scope=f"the failed delegate's transcript ({FAILED_T}), its meta.json, its scratch directory "
              f"({AITOOLS}/.scratch/session-874d-8-cns/), and its expected AAR path",
        out_of_scope=["reviewing RFC 0011", "the thinking blocks of the failed transcript",
                      "the two running reviewers 874d-7 and 874d-9"],
        audience="the session agent dbd05b0c and the commander"),
    objectives=[
        OrderedDict(id="OBJ-1", type="objective", text=ORDER, source=src("commander", f"{TRANSCRIPT} L4290"), quote=ORDER),
        OrderedDict(id="OBJ-2", type="objective",
                    text="Report: (1) the failed delegate's timeline: what it read, ran and wrote, in order, with "
                         "transcript line numbers and timestamps, up to the last record; (2) what it was doing when it "
                         "stopped (the last tool call and visible text before the failure), without the thinking "
                         "blocks; (3) every work product it left: files in its scratch, an AAR file if any, findings "
                         "in its visible text or tool results, and for each whether it is complete, partial or "
                         "unusable, and why; (4) what the failure notice and the record metadata establish about the "
                         "cause, separated from what is unknown; (5) whether a relaunch can start from its work "
                         "product, and what the relaunch brief should change",
                    source=src("agent", f"session agent {SESSION_ID}, this brief")),
    ],
    constraints=[OrderedDict(text=t, source=src("agent", s)) for t, s in C],
    assumptions=[OrderedDict(
        id="ASM-1", type="assumption",
        text="The failed delegate's transcript and scratch files are complete and no longer written to",
        status="unverified", confidence="high",
        evidence="the failure notice reports the agent terminated; the transcript's mtime is 17:54 local",
        impact_if_false="a later record changes the timeline; report the file sizes and times you read",
        source=src("agent", f"session agent {SESSION_ID}"))],
    decisions=[],
    operational_learning=[
        OrderedDict(id="OL-1", type="operational_learning",
                    text="A session JSONL record has a type (user, assistant, queue-operation, system, ...); an "
                         "assistant record's message.content is a list of parts of type text, thinking or tool_use; "
                         "a user record's content holds tool_result parts. Skip parts of type thinking",
                    source=src("artifact", f"{AITOOLS}/.scratch/session-{SESSION_ID}/turns.py")),
        OrderedDict(id="OL-2", type="operational_learning",
                    text="The 874d-8 delegate was sent a correction by SendMessage after launch (read 10 more project "
                         "rules); it arrives in its transcript as a user record at its next tool round",
                    source=src("agent", "session agent dbd05b0c")),
        OrderedDict(id="OL-3", type="operational_learning",
                    text="Save copies of transcript content under a .tmp name in your scratch: the harvester copies "
                         "other top-level scratch files into the tracked harvesting/ of a public repo",
                    source=src("artifact", f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md section 7")),
    ],
    artifacts=[OrderedDict(path=p, instruction="read in full") for p in full] +
              [OrderedDict(path=p, instruction="use as reference for answers") for p in ref],
    deliverables=[OrderedDict(
        kind="aar", ref=f"{scratch}/{NAME}-aar.json", objective="OBJ-2",
        text="your AAR: JSON in the AAR schema of RFC 0011 3.4, the last fenced json block of your final message, "
             "and the same JSON in this file (requested)")],
)
path = f"{scratch}/{NAME}-brief.json"
with open(path, "w", encoding="utf-8") as f:
    json.dump(brief, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(path)
