## Delegation Duty

**Intent**: **Purpose**: Make the `/delegate` skill mandatory for every
delegation, at every level: the Session Commander and every delegate load it
before launching any agent or workflow, and every delegation prompt tells the
delegate to read all user- and project-scope rules and CLAUDE.md files and to
load `/delegate` itself, so the duty recurses to every delegate's delegates.
Record the delegation decisions. **Scope**: The decisions table, the trigger
directive (when `/delegate` must be loaded), the three things every
delegation prompt must make the delegate do, and the detection hook. NOT how
to write the prompt, the eight elements' detail, shipping, standing orders,
environment limits or verification (all in the `/delegate` skill, the single
body of delegation practice). NOT handoff production (`/handoff` skill).
**Audience**: Every agent that launches a delegate or receives a delegation
prompt, in any repo, on any platform and in any environment.

### Decisions

| ID | Decision | Date | By |
|----|----------|------|----|
| D-DEL1 | Delegation duty includes asking every delegate to write any `*.md` file with its name as a prefix (e.g. `S2-report.md`), on all platforms and in all environments | 2026-10-05 | commander |
| D-DEL2 | A delegation rule exists (this file) | 2026-10-05 | commander |
| D-DEL3 | A delegation skill exists (`/delegate`) | 2026-10-05 | commander |
| D-DEL4 | A delegate that produces a code change owns shipping it: it pushes its own branch and opens the PR itself. It does not hand the push back to the delegating agent or wait on the user | 2026-10-21 | commander |
| D-DEL5 | Delegates and agents write their documents and changes as versions (v1.0, v1.1, ...) in their final location, never as "drafts". Protected files are written as a version and committed; the commander reviews the diff after (review-after). His approval of the text after the fact replaces the pre-write draft gate. Outward-facing or destructive actions (merging, tagging, deleting, publishing) still need his explicit order or confirmation | 2026-10-26 | commander |
| D-DEL6 | Conflicting instructions are resolved in priority order: 1) the commander's own words, newest first (recent session transcripts, and the rules, standing orders and decision records that record his words); 2) the delegation prompt; 3) skills. A prompt cannot loosen a rule unless it quotes the commander. A mandated skill or rule is never dropped silently | 2026-10-26 | commander |
| D-DEL7 | The `/delegate` skill is the single body of delegation practice (the shared mission packet is merged into it); this rule holds only the decisions and the trigger, and never duplicates the skill. `/delegate` is loaded before every Agent tool call and every workflow, by every agent at every level | 2026-10-26 | commander |
| D-DEL8 | The delegating agent writes the delegate's mission objectives verbatim and explicitly in the delegation prompt, so the mission is in the delegate's context. The duty is recursive: a delegate that delegates does the same for each of its delegates, through the whole chain of command | 2026-11-15 | commander |
| D-DEL9 | A delegate reports a blocker (something that stops it from accomplishing an objective) to its delegating agent as soon as it finds it, with a recommended course of action; it does not hold it for its final report, where it records it again. This is a standing duty of every delegate on every mission; a mission brief does not restate it | 2026-11-15 | commander |
| D-DEL10 | The delegating agent writes a mission brief file for every delegate (issue #180 schema): `<session scratch dir>/<sid4>_<mission name>-brief.md`, where the session scratch dir is the top-level session's `.scratch/session-<session id>/` and `<sid4>` is the last four hex digits of the top-level session id. The delegation prompt gives the brief's path and the explicit instruction to read it in full, line by line, before any other work. The naming convention is in `/delegate` "Mission brief file" | 2026-11-15 | commander |
| D-DEL11 | A delegate's final report is its after action review (AAR, issue #180 schema). The free-text report lines fold into its nodes: a denied write or other blocker is a deviation, a `CONFLICT:` line an ambiguity, an `INCIDENT:` marker an observation, PR URLs and files an objective's deliverables | 2026-11-15 | commander |
| D-DEL12 | Only structured content goes in the mission brief. Anything unstructured, such as facts or background, goes in the body of the delegation prompt, outside the brief | 2026-11-15 | commander |
| D-DEL13 | Every delegate loads `/delegate` at start, before any other work, so the standing duties (conflict priority, `WRITE_BLOCKED`, reporting blockers at once, objectives verbatim down the chain) reach it from the skill and this rule; a mission brief does not restate them | 2026-11-15 | session agent dbd05b0c, review after (D-DEL5) |

### Governing principle

A delegate starts with none of the delegating agent's conversation, and what
Claude Code gives it varies by launch path (Agent tool, Workflow `agent()`,
built-in types such as Explore and Plan, background and cloud sessions).
Everything it needs must be in its delegation prompt. The delegating agent
stays accountable for the delegate's output. The duty is recursive: a
delegate that delegates bears it toward its own delegates.

### Trigger directive: load /delegate (MUST)

Invoke the `/delegate` skill (the Skill tool, `skill: "delegate"`) BEFORE:

- **every Agent tool call**, of any `subagent_type` (general-purpose,
  Explore, Plan, claude-code-guide, custom agents), foreground or
  `run_in_background`;
- **every Workflow tool call**, and before writing any workflow script: each
  `agent()` prompt in the script is a delegation prompt;
- starting a parallel, background or cloud session, or writing a mission
  brief or pre-positioned prompt for one;
- relying on what a delegate returned (the skill's verification steps).

Load it up front: at session start, before the first delegation, and again
after a context compaction. Also invoke it when the `delegation-duty-guard`
hook prints a reminder, when planning a delegation chain, and when the user
says `/delegate`. A Session Commander that launches a delegate without having
loaded `/delegate` in the current context has broken this rule.

### What every delegation prompt makes the delegate do

Every delegation prompt (Agent tool prompt, workflow `agent()` prompt,
session brief) carries the eight elements in the `/delegate` skill
(identity; rules and CLAUDE.md files; skills, `/delegate` first;
operational learning; conflict priority; `WRITE_BLOCKED`; access; name
prefix). Three of them carry the recursion and are never left out:

1. **Read every rule and CLAUDE.md file**: an explicit instruction to read in
   full, before other work, every user-scope and project-scope CLAUDE.md and
   rule (`~/.claude/CLAUDE.md`, every `~/.claude/rules/*.md`,
   `<repo>/CLAUDE.md`, every `<repo>/.claude/rules/*.md`), listed by
   absolute path. Never assume the delegate inherited them.
2. **Load `/delegate`**: an explicit instruction to load the `/delegate`
   skill at start, before any other work (D-DEL13), and in any case before
   launching any delegate of its own.
3. **Pass it on**: an explicit instruction to give every one of its delegates
   the same two instructions and this one, so the duty reaches every level.

### What the delegate owes back

What the skill lists ("The delegate owes back"): its after action review
(AAR, D-DEL11) as its final report, with a denied write recorded as a
deviation and reported at once (D-DEL9), each `CONFLICT:` as an ambiguity
resolved by D-DEL6, each `INCIDENT:` marker as an observation, and its PR
URLs and files as deliverables; output at the designated path with
name-prefixed Markdown (D-DEL1), scope adherence, cited sources, versions
not drafts (D-DEL5), and for a code change its pushed branch and PR URL
(D-DEL4).

### Detection

Two aitools hooks (`shared/hooks/`) remind the caller to load `/delegate` and
check the eight elements, in observe mode: `delegation-duty-guard.sh`
(PreToolUse on the Agent tool) checks the Agent prompt, and
`workflow-delegation-guard.sh` (PreToolUse on the Workflow tool) checks each
`agent()` prompt in the workflow script. Mechanisms the hooks cannot see (cloud
agents, manually started sessions) rely on this rule and the skill alone.

### Cross-references

- Everything about writing, shipping and verifying delegations: `/delegate`
  skill
- Handoffs: `/handoff` skill (written by the session agent itself and
  printed in the terminal, with no delegates and no artifacts unless the
  commander asks; tested on Claude Code, other harnesses not yet tested)
- Claude Code limits behind the elements: `/tool-ops` skill (the
  `/aitool-ops` card is retired)
- Mission monitoring: `/mission-control` skill
- Governed terms (delegate, delegating agent, delegation duty): `/glossary`
  skill (aitools repo)
