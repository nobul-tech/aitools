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
   skill before launching any delegate of its own.
3. **Pass it on**: an explicit instruction to give every one of its delegates
   the same two instructions and this one, so the duty reaches every level.

### What the delegate owes back

What the skill lists ("The delegate owes back"): `WRITE_BLOCKED` on any
denial, output at the designated path with name-prefixed Markdown (D-DEL1),
`INCIDENT:` markers, `CONFLICT:` lines (D-DEL6), scope adherence, cited
sources, versions not drafts (D-DEL5), and for a code change its pushed
branch and PR URL (D-DEL4).

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
- Handoff delegations: `/handoff` skill
- Claude Code limits behind the elements: `/aitool-ops` skill
- Mission monitoring: `/mission-control` skill
- Governed terms (delegate, delegating agent, delegation duty): `/glossary`
  skill (aitools repo)
