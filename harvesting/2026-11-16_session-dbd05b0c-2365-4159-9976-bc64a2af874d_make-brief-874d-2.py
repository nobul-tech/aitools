"""Write the implementing mission's brief, 874d-2-structured-reports-brief.json, v1.1 (RFC 0011 v1.2, 3.3).

Usage: make-brief-874d-2.py <issue body v5.4 file> <session scratch dir>

Decision items are copied from the issue's decision table (D874d-1 to D874d-70), so no quote
is retyped; the few quote and location fixes the verifiers found are applied below by id.
Objective sources point to the plan's work-package headings by path:line. The four verifier
briefs (874d-3 to 874d-6) are records of launched missions and are not regenerated.
"""
import json
import re
import sys
from collections import OrderedDict
from datetime import datetime, timezone

body_path, scratch = sys.argv[1], sys.argv[2]
body = open(body_path, encoding="utf-8").read()

SESSION_ID = "dbd05b0c-2365-4159-9976-bc64a2af874d"
TRANSCRIPT = f"/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/{SESSION_ID}.jsonl"
AITOOLS = "/Users/new-jose/repos/aitools"
HOME = "/Users/new-jose"
PLAN = f"{AITOOLS}/plans/structured-reports/implementation-plan.md"
RFC = f"{AITOOLS}/rfcs/RFC-0011-structured-reports.md"
MISSION = "874d-2-structured-reports"
CREATED = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
S87795 = "session 87795dc3 L8030 (transcript not on this machine; verified through issue #180 section 1 and its comment \"Commander's answers (2026-11-15)\")"


def src(kind, location):
    return OrderedDict(kind=kind, location=location)


# ---- decisions ------------------------------------------------------------------------
SESSION_ONLY = {"D874d-38", "D874d-40", "D874d-45", "D874d-46", "D874d-59", "D874d-63", "D874d-69",
                "D874d-75", "D874d-77"}
WHOLLY_SUPERSEDED = {"D874d-2", "D874d-3", "D874d-4", "D874d-39", "D874d-62"}
SUPERSEDED_BY = {
    "D874d-1": [("D874d-19", "the node set"), ("D874d-22", "the node set"), ("D874d-29", "the node set")],
    "D874d-7": [("D874d-35", "the format choice"), ("D874d-42", "the format choice")],
    "D874d-8": [("D874d-35", "\"as json\"")],
    "D874d-16": [("D874d-26", "the list of conditions in the prompt")],
    "D874d-30": [("D874d-66", "the glossary requirement, for now")],
    "D874d-36": [("D874d-42", "the name and the format")],
    "D874d-42": [("D874d-47", "the AAR file")],
}
QUOTE_FIX = {
    # 874d-5 OBS-8 / 874d-3 OBS-15: the words of the decision are answer 3, not the later question.
    "D874d-8": ("one per session, as json, all delegates edit directly, json allows for this right? the multi-writer, "
                "without issue? its the main reason to do json", S87795),
    # 874d-5 OBS-9 / 874d-3 OBS-16: one verbatim span of L2160, not two fragments joined.
    "D874d-51": ("26) the sessionend hook should commit and push to main.  the stored json estimate should actually "
                 "live in my dotprofile repo actually, thats a decision.  there should be a directory called \"running "
                 "estimates\" and thats where they should live.  the session end hook should commit/push the user "
                 "dotprofile repo.", f"{TRANSCRIPT} L2160"),
    "D874d-1": (None, "/Users/new-jose/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_79b05dd0.jsonl L419"),
    # The row's quote is followed by a note ("Shipped in PR #181"), which the parser does not expect.
    "D874d-6": ("have this mission decide on rfi 44 as well. having intelligence types we dont use is not a big deal "
                "but i agree with you that FINDING is redundant.",
                "session 87795dc3, order 43 (transcript not on this machine; verified through issue #180 section 1)"),
}
COMMANDER_WORDS = {"D874d-6"}  # decided by a mission under the commander's order; the quote is his

decisions = []
for row in body.splitlines():
    m = re.match(r"^\| (D874d-\d+) \| (.*?) \| (\d{4}-\d{2}-\d{2}) \| (.*?) \| (.*) \|$", row)
    if not m:
        continue
    did, text, date, by, source = m.groups()
    if did in SESSION_ONLY or did in WHOLLY_SUPERSEDED:
        continue
    core = re.sub(r"\s*\([^()]*\)\s*$", "", source) if source.endswith(")") else source
    hits = re.findall(r'(Session dbd05b0c L(\d+)(?:, on [^:]+)?: |L(\d+)(?:, on [^:]+)?: |: )"(.*?)"(?=$|\. |; | and )', core)
    quote, location = "", ""
    if hits:
        lead, l1, l2, quote = hits[-1]
        line = l1 or l2
        if line and "87795dc3" not in lead:
            location = f"{TRANSCRIPT} L{line}"
    if "87795dc3" in core and not location:
        location = S87795
    if did in QUOTE_FIX:
        q, loc = QUOTE_FIX[did]
        quote = q if q is not None else quote
        location = loc
    if not location:
        location = "issue nobul-tech/aitools#180 body v5.4, section 1"
    item = OrderedDict(id=did, type="decision", text=text, decided_by=by, date=date,
                       source=src("commander" if by == "commander" or did in COMMANDER_WORDS else "agent", location),
                       quote=quote, status="decided")
    if did in SUPERSEDED_BY:
        item["superseded_by"] = [OrderedDict(decision=d, part=p) for d, p in SUPERSEDED_BY[did]]
    decisions.append(item)

# ---- objectives -----------------------------------------------------------------------
plan_lines = open(PLAN, encoding="utf-8").read().splitlines()
WP_HEADINGS = [
    "WP-1: reference, schemas, templates, validation",
    "WP-2: the harness text, in line with RFC 0011 (D874d-49)",
    "WP-3: session DB, schema 5 (RFC 0011 section 3.6)",
    "WP-4: hooks, the SessionEnd job, the harvester (RFC 0011 3.4, 3.5.5, 3.9.3, section 7)",
    "WP-5: the skills and readers that use the documents (D874d-61)",
    "WP-6: release",
]
objectives = [OrderedDict(
    id="OBJ-1", type="objective", text="implement structured running estimates, briefings, aars",
    source=src("commander", "issue nobul-tech/aitools#180, Objective; session 87795dc3 (transcript not on this machine)"),
    quote="implement structured running estimates, briefings, aars")]
for n, heading in enumerate(WP_HEADINGS, 2):
    line = plan_lines.index(f"## {heading}") + 1
    objectives.append(OrderedDict(id=f"OBJ-{n}", type="objective", text=heading,
                                  source=src("artifact", f"{PLAN}:{line}")))

# ---- constraints (what the delegate must do or must not do) ---------------------------
how_line = plan_lines.index("## How every batch is shipped (D-DEL4)") + 1
gates_line = plan_lines.index("## Gates") + 1
C = [
    ("Ship every work package as its own PR, based on main, from your own worktree made with git worktree add off "
     "origin/main (<aitools>/.scratch/worktrees/874d-2-structured-reports), on the branch "
     "feature/874d-2-structured-reports-wp<n>; a later work package's branch merges the earlier one in with --no-ff. "
     "Commit and push after every batch, with git commit -F.", f"{AITOOLS}/shared/rules/delegation.md D-DEL4; {PLAN}:{how_line}"),
    ("Do not merge: the commander merges the PRs, in order. Hand back your AAR when every work package's PR is open "
     "with CI green, or at once when a blocker stops you, with a recommended course of action. This overrides the "
     "/delegate duty to self-merge (D-DEL6: the brief ranks above the skill).", f"D-DEL5; D-DEL9; {PLAN}:{how_line}"),
    ("Never push to main, force-push, or approve your own PR. Update the plan's status table after each batch in the "
     "work package's branch (D874d-60); do not write .aitools/channel/relay.md, a direct-to-main file.",
     f"{TRANSCRIPT} L3394 (D874d-60); {PLAN}:{how_line}"),
    ("Launch an independent reviewer (a delegate that did not see your notes) for every PR; its verdict is a PR "
     "comment before the PR goes to the commander.", f"{PLAN}:{how_line}"),
    ("Before every push run bash scripts/check-pre-commit.sh and bash scripts/check-pre-push.sh (on Windows the .ps1 "
     "twins with pwsh -NoProfile -File). Every new test suite gets a step in each job of .github/workflows/check.yml "
     "that runs it; watch CI until it passes on macOS, Linux and Windows.", f"{AITOOLS}/CLAUDE.md; {PLAN}:{how_line}"),
    ("WP-1 starts on your launch order (gate G0). Before WP-2, check that the six working-copy files of session "
     "dbd05b0c are on origin/main (gate G1); if they are not when WP-1 is done, raise an RFI and do not edit "
     "origin/main's versions of them.", f"{PLAN}:{gates_line}"),
    ("Do not reopen the decisions of issue #180 section 1; a point you find unclear goes to the commander as an RFI "
     "with a suggested answer.", f"{RFC}, Status of this memo"),
    ("Python is standard library only, at the floor scripts/harness-db.py states (Python 3.10 or later).",
     f"{AITOOLS}/rfcs/0010-python-sqlite-engineering.md section 2; {RFC} section 6"),
    ("A new or widened hook check starts in observe mode and passes the syntax, smoke and violation tests of "
     ".claude/rules/hook-rollout.md.", f"{AITOOLS}/.claude/rules/hook-rollout.md"),
    ("Never run aitools, aitools install, setup-user-*, deploy-harness or scripts/build-deploy.sh against the real "
     "HOME; tests use an isolated HOME.", f"{HOME}/.claude/skills/delegate/SKILL.md 'In the aitools repo'"),
    ("Never open a live session DB or the harness DB with a branch's or worktree's harness-db.py: tests and probes "
     "use throwaway copies (sqlite3 backup API).", f"{RFC} 3.6.12"),
    ("Never push to the real dotprofile: tests use a clone whose origin is a local bare repo in your scratch, "
     "checked before every push (git remote get-url origin must not contain github.com).", f"{PLAN} batch 4.3"),
    ("Never commit a mission brief, an AAR, a running-estimate export, or a harvested copy of one "
     "(harvesting/*-brief.json, harvesting/*-aar.json), to a project repo, except a brief the commander orders into "
     "the briefs directory, as he ordered this one (D874d-71 to D874d-74). The briefs of your batch delegates stay "
     "in the session scratch directory. How a new version of a brief in the briefs directory reaches main is "
     "deferred by the commander (D874d-76): until he decides, it reaches main through a PR, unless he orders "
     "otherwise for that change (RFC 0011 3.3.1a). Citing the commander's decisions in rules, references and the glossary is "
     "allowed, as the repo already does.", f"{RFC} section 7, 3.3.1"),
    ("This brief is a long-lifecycle brief in the briefs directory. If you are launched in a session other than "
     "dbd05b0c, the launching agent first writes a new version of it whose provenance describes that session "
     "(RFC 0011 3.3.1a); report into the session named in provenance.", f"{RFC} 3.3.1a"),
    ("Change the glossary only in batch 2.2 and only through /glossary; add no glossary entries for the schema's "
     "nodes and fields (D874d-66).", f"{TRANSCRIPT} L3479 (D874d-66, D874d-67)"),
    ("Read every file in full before you change it. The files marked 'use as reference for answers' in artifacts are "
     "what you need to brief the delegates of your batches; give each such delegate its batch's files as "
     "'read in full' artifacts, in a brief written by RFC 0011 3.3 into the top-level session's scratch directory, "
     "the default location (RFC 0011 3.3.1).",
     f"{RFC} 3.3.3a; {PLAN}:{how_line}"),
    ("Where the deployed /delegate (~/.claude/skills/delegate/SKILL.md) differs from the aitools working copy "
     "(shared/skills/delegate/SKILL.md) or from RFC 0011, follow RFC 0011 and issue #180 (D-DEL6: the commander's "
     "newest words).", f"{HOME}/.claude/rules/delegation.md D-DEL6"),
]
constraints = [OrderedDict(text=t, source=src("agent", s)) for t, s in C]

# ---- assumptions (issue #180, ASM-1 to ASM-8) -----------------------------------------
ASM_SRC = "issue nobul-tech/aitools#180, comment \"Sections 5 and 6 (moved in v5.4)\", section 6"
A = [
    ("ASM-1", "A running delegate can learn its own agentId (D874d-33)", "unverified", "moderate",
     "/delegate 'Claude Code specifics': a TaskStop error, the parent transcript; and subagents/agent-<agentId>.meta.json, "
     "which existed while the background verifiers 874d-3 to 874d-6 ran (2026-11-16). Foreground delegates are not probed",
     "its rows carry no agent_id; the delegating agent fills it from the agentId the launch returned (RFC 0011 3.4.9)", None),
    ("ASM-2", "SQLite in WAL mode with a 5-second busy timeout takes the session agent and several parallel delegates writing at once, without errors",
     "unverified", "moderate",
     "partly verified: WAL, busy_timeout=5000 and BEGIN IMMEDIATE are in scripts/harness-db.py; no load test",
     "'database is locked'; agents retry, hooks do not (RFC 0011 3.6.6)", None),
    ("ASM-3", "Every delegate can run ~/.aitools/bin/harness-db.py and write the session DB in the main checkout", "unverified", "low",
     "/delegate 'Environment limits': worktree isolation confines writes to the worktree",
     "the delegating agent records the delegate's items from its AAR (RFC 0011 3.4.8)", None),
    ("ASM-4", "A delegating agent at level 2 or deeper can write its delegates' briefs into the top-level session's scratch directory",
     "unverified", "low", "the same isolation limit",
     "the brief goes in the delegating agent's own scratch directory (RFC 0011 3.3.8)", None),
    ("ASM-5", "The session agent knows its session id and its DB path from the start", "verified", "high",
     "scripts/harness-db.py prints 'Session started:' and 'Session DB:'; the SessionStart hook shows them",
     "the session agent cannot pass --db or --agent-id", "scripts/harness-db.py session start output"),
    ("ASM-6", "The first 10 characters of a session id are unique within one repo", "unverified", "high",
     "36 bits makes a collision unlikely; not tested",
     "two sessions would share a DB; checked at session start, and the second uses its full id (RFC 0011 3.6.2)", None),
    ("ASM-7", "The brief, the AAR and the export can be checked against JSON Schemas with tools aitools already manages",
     "falsified", "high", "Python's standard library has no JSON Schema validator",
     "a new dependency, or hand-written checks", "RFC 0011 S-6: a standard-library validator of the schema subset, plus coded rules (3.7.2)"),
    ("ASM-8", "The six working-copy files of session dbd05b0c reach origin/main before WP-2 starts", "unverified", "moderate",
     "the commander takes care of them (R874d-27: \"27) dont worry about it\")",
     "gate G1 stays open: WP-2 waits; WP-1 does not (plan, Gates)", None),
]
assumptions = []
for i, t, st, cf, ev, imp, ref in A:
    a = OrderedDict(id=i, type="assumption", text=t, status=st, confidence=cf, evidence=ev, impact_if_false=imp)
    if ref:
        a["ref"] = ref
    a["source"] = src("agent", ASM_SRC)
    assumptions.append(a)

# ---- operational learning -------------------------------------------------------------
OL = [
    ("The deployed /delegate (~/.claude/skills/delegate/SKILL.md) can be older than the aitools working copy "
     "(shared/skills/delegate/SKILL.md v2.6), and RFC 0011 and issue #180 are newer than both; where they differ, "
     "follow the commander's newest words (D-DEL6)", src("agent", f"session dbd05b0c, {TRANSCRIPT}")),
    ("A delegate's subagents/agent-<agentId>.meta.json, whose description starts with its mission name, existed while "
     "the four background verifiers 874d-3 to 874d-6 ran (2026-11-16); for 874d-1-aar-doctrine it was seen only at "
     "finish, a file time that is rewritten then. Look for it first; fall back to a TaskStop error or the parent transcript",
     src("telemetry", f"{HOME}/.claude/projects/-Users-new-jose-repos-aitools/{SESSION_ID}/subagents/ (ls, 2026-11-16)")),
    ("ait-harvest.py archive copies transcripts into the dotprofile and commits and pushes them, detached, because "
     "Claude Code gives SessionEnd hooks a 1.5-second default window; but it takes no lock, and "
     "~/.aitools/logs/ait-harvest.log holds about 60 git failures, mostly index.lock contention. RFC 0011 3.5.5 "
     "requires one detached job with a lock and a rebase", src("telemetry", f"{HOME}/.aitools/logs/ait-harvest.log; mission 874d-4-adversarial OBS-4")),
    ("A schema-4 harness-db.py crashes on a schema-5 DB: migrate_v4 runs before the version check, and on a throwaway "
     "DB the probe hit 'use DROP VIEW to delete view observations'. Batch 3.0 ships the version check first",
     src("telemetry", "mission 874d-4-adversarial OBS-1 (probe on a throwaway DB, SQLite 3.53.1)")),
    ("Another session can edit the same working-copy files at the same time (commit 3893c908 staged only its own "
     "lines with git update-index); run git log and git diff on a shared file before editing it",
     src("agent", f"session dbd05b0c, {TRANSCRIPT}")),
    ("The 10-character session id prefix includes the UUID's first hyphen (dbd05b0c-2.db)",
     src("artifact", f"{AITOOLS}/scripts/harness-db.py session_prefix; D874d-48")),
    ("The harvester copies every non-ephemeral top-level file of a session scratch directory into the tracked "
     "harvesting/ of a public repo; *.json files are ephemeral only when named package-lock*, node_modules*, tsconfig* "
     "or *.config.json. Until batch 4.5 ships, save copies of transcripts, prompts and issue bodies as *.tmp",
     src("artifact", f"{AITOOLS}/scripts/ait-harvest.py _is_ephemeral; {HOME}/.claude/skills/scratch/SKILL.md")),
    ("A message the commander sends while a turn is running is recorded in the transcript as a queue-operation record "
     "with a content field, not as a user record; a quote check must read both",
     src("telemetry", f"{TRANSCRIPT} L3589")),
    ("A GitHub issue body holds at most 65,536 characters; issue #180 moved sections to comments in v5.1 and v5.4",
     src("agent", "session dbd05b0c, issue #180 v5.1 and v5.4")),
    ("A mechanical schema check (keys, enums, quotes) passed the v1.0 brief completely; every substantive defect came "
     "from reading its constraints and access against the repo's rules. Pair any validate step with a sufficiency read",
     src("agent", "mission 874d-5-brief-verify OL-3")),
]
operational_learning = [OrderedDict(id=f"OL-{n}", type="operational_learning", text=t, source=s)
                        for n, (t, s) in enumerate(OL, 1)]

# ---- artifacts ------------------------------------------------------------------------
FULL, REF = "read in full", "use as reference for answers"
full = [f"{HOME}/.claude/CLAUDE.md"] + [f"{HOME}/.claude/rules/{n}.md" for n in (
    "delegation", "prompt-turn", "scratch", "tool-evaluation", "tool-lifecycle", "tool-ops", "web-sources")] + [
    f"{AITOOLS}/CLAUDE.md", f"{AITOOLS}/.aitools/channel/CLAUDE.md"] + [f"{AITOOLS}/.claude/rules/{n}.md" for n in (
    "agentic-standards", "aitools-workspace", "config-file-safety", "cross-platform", "deploy-paths",
    "documentation-standards", "frameworks", "git-safety", "glossary", "governed-data-access", "hook-lifecycle",
    "hook-rollout", "incident-governance", "interactive-menus", "managed-file-deployment", "script-standards",
    "smoke-test-pattern")] + [
    f"{AITOOLS}/shared/skills/delegate/SKILL.md",
    f"{AITOOLS}/shared/rules/delegation.md",
    f"{AITOOLS}/shared/skills/scratch/SKILL.md",
    f"{AITOOLS}/.claude/skills/glossary/SKILL.md",
    f"{AITOOLS}/shared/skills/intent-writing/SKILL.md",
    f"{AITOOLS}/shared/skills/intent-audit/SKILL.md",
    f"{AITOOLS}/shared/skills/tool-ops/SKILL.md",
    f"{AITOOLS}/.claude/skills/frameworks/SKILL.md",
    RFC, PLAN, f"{AITOOLS}/rfcs/0010-python-sqlite-engineering.md"] + [f"{AITOOLS}/reference/{n}" for n in (
    "script-standards-detail.md", "cross-platform-detail.md", "logging.md", "managed-file-deployment.md",
    "plan-execution-detail.md", "rules.md", "skills.md")]
ref = [TRANSCRIPT] + [f"{scratch}/{m}-aar.json" for m in (
    "874d-3-spec-verify", "874d-4-adversarial", "874d-5-brief-verify", "874d-6-standards-verify")] + [
    f"{AITOOLS}/.aitools/channel/handoffs/2026-11-15_dbd05b0c-missions/874d-1-aar-doctrine/874d-1-aar-doctrine-report.md",
    f"{AITOOLS}/rfcs/0005-v2-session-intelligence-architecture.md",
    f"{AITOOLS}/rfcs/0006-delegation-architecture.md",
    f"{AITOOLS}/reference/framework-mission-command.md",
    f"{AITOOLS}/reference/framework-intelligence-types.md",
    f"{AITOOLS}/reference/prompt-turn-checklist.md",
    f"{AITOOLS}/reference/README.md",
    f"{AITOOLS}/reference/harness-db-schema.sql",
    f"{AITOOLS}/reference/artifact-harvesting.md",
    f"{AITOOLS}/scripts/harness-db.py",
    f"{AITOOLS}/scripts/ait-harvest.py",
    f"{AITOOLS}/scripts/generate-dashboard.py",
    f"{AITOOLS}/scripts/aitools-dashboard.sh",
    f"{AITOOLS}/scripts/aitools-dashboard.ps1",
    f"{AITOOLS}/shared/hooks/harness-db-sessionstart.sh",
    f"{AITOOLS}/shared/hooks/harness-db-sessionend.sh",
    f"{AITOOLS}/shared/hooks/session-archive.sh",
    f"{AITOOLS}/shared/hooks/session-catchup.sh",
    f"{AITOOLS}/shared/hooks/intelligence-stop.py",
    f"{AITOOLS}/shared/hooks/delegation-duty-guard.sh",
    f"{AITOOLS}/shared/hooks/workflow-delegation-guard.sh",
    f"{AITOOLS}/shared/hooks/dashboard-serve.sh",
    f"{AITOOLS}/shared/hooks/hooks-manifest.json",
    f"{AITOOLS}/shared/skills/handoff/SKILL.md",
    f"{AITOOLS}/shared/skills/mission-control/SKILL.md",
    f"{AITOOLS}/shared/skills/aitool-continue/SKILL.md",
    f"{AITOOLS}/shared/skills/tool-eval/SKILL.md",
    f"{AITOOLS}/.github/workflows/check.yml",
]
artifacts = [OrderedDict(path=p, instruction=FULL) for p in full] + [OrderedDict(path=p, instruction=REF) for p in ref]

# ---- deliverables ---------------------------------------------------------------------
deliverables = [OrderedDict(kind="pr", ref="nobul-tech/aitools, base main", objective=f"OBJ-{n}",
                            text=f"{WP_HEADINGS[n - 2].split(':')[0]}: one PR from feature/874d-2-structured-reports-wp{n - 1}, CI green on macOS, Linux and Windows, with the reviewer's verdict as a PR comment")
                for n in range(2, 8)]
deliverables.append(OrderedDict(
    kind="aar", ref="", objective="",  # RFC 0011 v1.4 3.2.6: the AAR serves every objective
    text="your AAR, the hand-back: JSON in the AAR schema of RFC 0011 3.4, the last fenced json block of your final "
         "message (D874d-47, D874d-50); no file is requested"))

brief = OrderedDict(
    provenance=OrderedDict(
        document="mission-brief", schema_version=1, version="v1.3", mission=MISSION, session_id=SESSION_ID,
        session_db="", session_scratch=scratch,
        written_by=OrderedDict(agent_id=SESSION_ID, agent_type="session", mission=None),
        chain_of_command=[TRANSCRIPT], created_at=CREATED),
    identity=OrderedDict(name=MISSION, level=1, delegated_by=f"session agent {SESSION_ID}", parallel_missions=[]),
    intent=OrderedDict(
        purpose="Implement RFC 0011 (structured running estimates, mission briefs and AARs) through work packages "
                "WP-1 to WP-6 of the plan, each shipped as its own PR for the commander to merge",
        scope="WP-1 to WP-6 of plans/structured-reports/implementation-plan.md v1.1, batch by batch, each verified as the plan says",
        out_of_scope=["changing the decisions of issue #180 (D874d-1 to D874d-70)",
                      "the /debrief, /brief and /channel skills (D874d-11)",
                      "sharing estimates across sessions, and distributed sessions (D874d-9, D874d-10)",
                      "harnesses other than Claude Code, beyond recording what is found when they are examined (D874d-33)",
                      "the session content already in the public repo (D874d-54)",
                      "WP-0 (RFC 0011 and the plan, done by session dbd05b0c)"],
        audience="the commander, reviewing and merging each PR; every agent that will write or read briefs, AARs "
                 "and running estimates"),
    objectives=objectives,
    constraints=constraints,
    assumptions=assumptions,
    decisions=decisions,
    operational_learning=operational_learning,
    artifacts=artifacts,
    deliverables=deliverables,
)

path = f"{AITOOLS}/briefs/{MISSION}-brief.json"  # the briefs directory, on the commander's order (D874d-71)
with open(path, "w", encoding="utf-8") as f:
    json.dump(brief, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(path, "|", len(decisions), "decisions,", len(artifacts), "artifacts,", len(constraints), "constraints")
