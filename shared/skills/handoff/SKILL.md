---
name: handoff
description: "Write a handoff yourself, in the session that holds the
  conversation, and print it in full in the terminal: no step is
  delegated, and no file is written unless the commander asks for one.
  Use when the commander says /handoff, before a /compact the session
  will resume from, when ending a session, when context is getting
  large, or when switching machines. Tested on Claude Code; other
  harnesses not yet tested."
---

## Intent

Equip the session agent to write a handoff itself and print it in the
terminal, so that the accepting session (the same session after a
`/compact`, or another session the commander gives it to) continues with
the decisions, work in flight, open threads and exclusions it needs,
without the conversation the handoff came from. The agent writes it from
its own context and delegates no step: it holds the whole conversation,
and a delegate would start with none of it.

NOT for mid-session checkpoints (commit and continue). NOT for artifact
harvesting (`/harvest` skill). NOT for session planning (`/planning`
skill). NOT for monitoring running missions (`/mission-control` skill).
Consumed by: the session agent asked for a handoff; the agent that
resumes after `/compact` or accepts the handoff in another session; the
commander, who reads it in the terminal.

Version 2.0, 2026-11-15 (commander, session a9074793-c: "change handoff
skill so that the handoff happens at the terminal just like we did in
this round and is not delegated"). v1.x was an 8-step workflow in which
S2, S3 and Verifier subagents audited the session and wrote and verified
a handoff file; v2.0 retires it (its text is in this file's git history).

## Harness support

| Harness | Status |
|---------|--------|
| Claude Code | Tested: Claude Code 2.1.325, CLI, macOS, 2026-11-15, session a9074793-c. The handoff was printed as the last reply, the commander ran `/compact`, and the resumed session found it word for word after the compaction summary and confirmed it against the session transcript. Detail: aitools `reference/tool-ops-claude-code.md` item #36 |
| Other harnesses aitools supports (Cursor CLI `agent`, Cursor IDE, Cursor cloud agents) | Not yet tested. Whether their compaction or summarisation keeps the last reply word for word is unknown: do not assume it does |

Claude Code on Windows and Claude Code web run the same harness but were
not part of the test. On an untested harness or environment: tell the
commander before he compacts that this is untested there; after the
compaction, the accepting agent checks the handoff against the session
transcript (where the harness keeps one) or asks the commander to paste
it back; report the result as a session RFI so this table and the
harness's ops reference can be updated.

## When to use

Invoke `/handoff` when ANY of these arise:

- The commander says `/handoff` or asks to wrap up the session
- The session will be compacted (`/compact`) and resumed (the tested case)
- Context usage exceeds 60% and significant work remains
- The session has uncommitted decisions, investigations or work in
  flight that the accepting session needs
- The commander is switching machines: suggest a file as well (see "When
  the commander asks for a file")
- The session has run 3+ hours with several work streams

## German doctrine concepts

This skill applies four concepts from German military doctrine. They are
used as thinking tools, not formal frameworks:

- **Schwerpunkt** (point of main effort): Every handoff declares a single
  decisive objective for the accepting session. There is exactly one. Work
  that does not serve it is deferred or excluded.
- **Lagebeurteilung** (situation assessment): Structured assessment of
  session state before writing the handoff. Walks through specific
  categories (forces, terrain, time, logistics) rather than free-form
  summary.
- **Reibung** (friction): Explicit inventory of what makes the handoff
  difficult -- large scratch directories, decisions that exist only in
  conversation, dependency chains, context constraints. Friction is
  planned for, not ignored.
- **Mitdenken** (thinking along): The skill thinks about the USER's
  intent, not just the mechanical steps. If the user wants to hand off
  plan-writing, the skill ensures the accepting session can write the
  plan -- not just that it has a list of decisions.

## Rules

1. **Yourself, no delegation.** Write the handoff in the session that
   holds the conversation. Launch no subagent, workflow or background
   session for any step: not the audit, the assessment, the writing or
   the verification. A delegate starts with none of the conversation
   (`/delegate` skill) and would rebuild it from files, losing what exists
   only in the conversation. A delegated step the commander orders himself
   is a delegation under the `/delegate` skill.
2. **In the terminal.** Print the whole handoff in your reply, in full,
   never a summary of it. Write no file unless the commander asks for one.
3. **Last before `/compact`.** When the session will resume after
   `/compact`, the handoff is the last reply before it: no other reply and
   no tool call after it. In the Claude Code test the compaction kept that
   last reply word for word and summarised everything before it, including
   the prompt that asked for the handoff (item #36).
4. **Self-contained.** The accepting agent may have only the handoff and a
   summary. Everything it needs for its first actions is in the handoff;
   files give depth.
5. **The commander's words win.** Where his request for the handoff says
   otherwise (a file, a location, a form), do what he says (D-DEL6, user
   rule `delegation.md`).

## Process

Every step runs in your own thinking and context. No step uses a
subagent.

### Step 1: Schwerpunkt

The Schwerpunkt of the accepting session is its single decisive
objective. Use the commander's if he named one. Otherwise derive it from
the conversation (usually the work in flight, or the next step he
ordered) and state it in the handoff. Ask him only when two objectives
are equally plausible and the choice changes what the accepting session
does: then raise a session RFI with your suggested answer.

### Step 2: Re-read and assess (Lagebeurteilung)

1. Re-read the whole conversation at full fidelity (prompt-turn checklist
   item 1, user rule `prompt-turn.md`). Restore any part already compacted
   from the session transcript, never from memory or a summary.
2. Collect the state: `git status` and the branch of each checkout the
   session touched; commits and PRs made; delegates still running (mission
   name, how to find its agent id and how to reach it; in Claude Code, the
   `.meta.json` under the session's `subagents/` directory whose
   `description` starts with the mission name); the session scratch
   directory; open session RFIs; the next RFI and mission numbers.
3. Walk the categories: **Forces** (committed and uncommitted work,
   decisions, investigation products), **Terrain** (who accepts: the same
   session after `/compact`, or a fresh session, on this machine or
   another), **Time**, **Logistics** (which files are current, which are
   stale), **Assumptions** (each with what breaks if it is false), and
   **Reibung** (what makes this handoff hard, and how the handoff
   mitigates it).
4. Set the exclusions: what the accepting session must not do, each with
   its reason; hard (only the commander can lift it) or soft.

### Step 3: Draft in full

Draft the whole handoff in thinking, every line in final form
(prompt-turn checklist item 7). Open with the staleness note: "If
anything has happened since this was written, re-check before acting:
... Verify against the files and GitHub; don't assume this snapshot is
still current." Then these sections; adapt the labels to the content and
merge small ones:

A. **Source of truth**: the authoritative files, in reading order; the
   session transcript path and how to read it.
B. **In flight**: running delegates and missions: name, order, what they
   will return, how to reach them.
C. **Schwerpunkt**: the objective, the priority sequence, the first
   actions.
D. **What this session built**: committed work; decisions with enough
   detail to act on, quoting the commander's words where they decide
   something; investigation products.
E. **Exclusions**: hard and soft, each with its reason.
F. **Open threads**: each READY, BLOCKED or DEFERRED; every open session
   RFI in full; the next RFI and mission numbers.
G. **Operational learning** carried forward.
H. **New concepts** (when there are any): new terms, frameworks or
   patterns the accepting agent needs.
I. **Provenance**: version, date, who wrote it, at whose request, how it
   was reviewed.

Layer the content: Layer 1, in the handoff, is everything the accepting
agent needs without reading another file; Layer 2 is the referenced files
(absolute paths) for depth; Layer 3 is background (transcripts, framework
references) for tracing a decision's origin.

Paths: for the same session after `/compact`, on the same machine, local
paths (the scratch directory, transcripts) are valid. A handoff that
another machine will read cites tracked paths only: `.scratch/` is
gitignored, and transcripts stay on the machine except through the
session archive.

### Step 4: Review it yourself

Attack the draft in thinking against these criteria, fix what fails, and
repeat until a pass finds nothing (prompt-turn checklist item 8):

1. **Self-containment**: the first actions are possible from the handoff
   alone.
2. **Reference integrity**: every path exists (check it on disk) and
   reaches the reader (same machine, or tracked).
3. **Reading order**: situation, then work in flight, the objective,
   background; no circular dependencies.
4. **Scope**: one Schwerpunkt; exclusions are specific and give reasons;
   a clear line between "do now" and "defer".
5. **Completeness**: every decision, open thread, running delegate and
   work product appears.
6. **Consistency**: no contradictions; section labels do not collide
   with decision identifiers (never "D3" as both).
7. **Harness correctness**: no feature the harness lacks is assumed; how
   to reach delegates is right for this harness.
8. **Ambiguity**: undefined terms, vague instructions, words with two
   meanings.
9. **Barrier test**: walk the accepting agent's first actions; where
   would it stop or be confused?

No independent verifier reviews it. Say so in Provenance: "self-reviewed
against the 9 criteria; not independently verified".

### Step 5: Print it

Print the handoff in full as your reply: the handoff first, then the
turn record where the prompt-turn checklist applies, in the same reply,
so the handoff stays in the last message. Name the next step in that
reply: "run `/compact`" (same session) or "start the accepting session
with this handoff" (another session).

A terminal handoff commits nothing: there is no file. A work product the
handoff cites (a plan, a report) is either committed under its own rules
before you print, or listed in the handoff as uncommitted, with where it
is.

### After `/compact`: the accepting agent

1. Find the handoff: in Claude Code, the reply kept word for word after
   the compaction summary.
2. Check it is complete when an action depends on its exact words: search
   the session transcript for a phrase unique to the handoff (aitools:
   `python3 ~/.aitools/bin/read-session.py <transcript> --search "<phrase>"`,
   output saved to your session scratch directory) and compare. The
   Claude Code summary names the transcript path.
3. Treat the summary as compressed: re-read from the transcript anything
   an action depends on word for word. The Claude Code summary says it was
   written without seeing the kept messages, so where the two disagree on
   what has happened, the kept messages are newer.
4. Re-check the staleness items (missions may have reported, branches
   may have moved), then act on the Schwerpunkt.

## When the commander asks for a file

Write a file only when the commander asks for one (for example to switch
machines, or to hand off to another session):

- Write it yourself, steps 1 to 4 as above; do not delegate.
- Path: `.aitools/channel/handoffs/<UTC date>_<session-prefix>.md`
  (tracked; in aitools it is committed directly to main under CLAUDE.md
  "Channel exception"). In a repo without `.aitools/`, a tracked path such
  as `plans/<briefing-name>/handoff-<date>_<prefix>.md` (e.g.,
  `plans/mission-command-briefing/handoff-2026-03-19_Z1IhGrcgGO.md`).
- Never in scratch: `.scratch/` is gitignored and never leaves the
  machine (the SessionEnd harvester copies a scratch file named
  `handoff*` to `.aitools/channel/handoffs/`, renamed).
- Cite tracked paths only.
- At session start, aitools announces the newest file in
  `.aitools/channel/handoffs/` (SessionStart hook `scratch-init.sh`).
- Commit it, run the repo's checks, and push under the repo's rules
  (aitools: "Channel exception").
- Print it in the terminal as well, unless he says otherwise.

## Handoff quality criteria

A good handoff satisfies all of these:

| Criterion | What it means |
|-----------|---------------|
| **Self-contained** | The accepting session can understand the mission from the handoff alone |
| **Layered** | Essential content is inline; depth is by reference |
| **Scope-governed** | Schwerpunkt declares focus; exclusions prevent drift |
| **Actionable** | First actions are specific and achievable |
| **Unambiguous** | No naming collisions, no undefined terms, no vague instructions |
| **Self-reviewed** | Reviewed against the 9 criteria by the session agent that wrote it; Provenance says it was not independently verified |
| **Complete** | Every decision, thread, running delegate and work product is accounted for |
| **Harness-correct** | What it relies on from the harness (compaction, how to reach delegates) is stated for the harness in use, and was tested there or flagged as untested |
| **Consistent** | Does not contradict itself or prior handoffs |
| **In the terminal** | Printed in full as the last reply before `/compact`; a file only when the commander asked for one |

## Adapting to project context

This skill works in any project. The depth adapts:

**Simple project (few decisions, one work stream)**: the handoff may be a
single page.

**Complex project (many decisions, several work streams)**: layering is
essential, naming collisions become likely, and the review takes more
passes.

**Project with an existing handoff**: read it, carry its content forward
or mark it superseded, and say which in Provenance.

## Lagebeurteilung as general-purpose capability

The Lagebeurteilung categories (Forces, Terrain, Time, Logistics,
Assumptions) are not specific to handoffs. They apply at any
transition point where context may be lost or assumptions may fail.

### Where Lagebeurteilung walkthroughs are needed

| Transition point | Why | Key categories |
|-----------------|-----|----------------|
| **Session end** (handoff) | Full context transfer | All five |
| **Session start** | Assess inherited state, detect drift | Forces (what exists), Terrain (what changed), Assumptions (what prior session assumed) |
| **Delegation** (subagent launch) | Subagent lacks parent context | Terrain (context gap), Logistics (what files exist), Assumptions (Write access, scratch persistence) |
| **Batch boundary** (plan execution) | Fresh subagent per batch | Forces (what prior batches produced), Time (remaining work), Assumptions (prior batch correctness) |
| **Incident response** | Rapid situation assessment | Forces (what is broken), Time (urgency), Logistics (what tools/access available) |

### Walkthrough protocol

At each transition point, the agent walks through the applicable
categories and asks "what are you assuming?" for each. The assumption
flush is the most valuable step -- 8 of 8 false assumptions in the
exit-code-1 investigation would have been caught by an explicit
walkthrough.

Each assumption gets tracked with:
- What is assumed
- Who assumed it (agent identity)
- When (session timestamp)
- Status: unverified (default) / verified (confirmed) / falsified (contradicted)
- Impact if falsified

## Cross-References

- Prompt-turn checklist (re-read, draft, review, deliver): user rule
  `prompt-turn.md`
- Compaction in Claude Code (what `/compact` keeps word for word): aitools
  `reference/tool-ops-claude-code.md` item #36; `/tool-ops` skill
- Reading session transcripts: `/delegate` skill, "Reading the
  commander's sessions"
- Delegation duty (a handoff is not delegated; this covers work handed to
  delegates): `/delegate` skill, user rule `delegation.md`
- Session planning: `/planning` skill
- Scratch files: `/scratch` skill
- Investigation methodology: `/investigate` skill
- Intent writing: `/intent-writing` skill (for intent on new files)
- History of the retired v1 workflow:
  `plans/mission-command-briefing/delegation-evolution.md` (how
  delegation duty was developed through 7 user interventions) and
  `plans/mission-command-briefing/handoff-prompt.md` (the first handoff
  that workflow produced)
- Governed vocabulary: `/glossary` skill (aitools sessions; terms:
  handoff, accepting session, delegating agent, delegate, delegation
  duty, lifecycle transition, assumption, Schwerpunkt, Lagebeurteilung,
  Reibung, Mitdenken, Auftrag)
