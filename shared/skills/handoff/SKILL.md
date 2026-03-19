---
name: handoff
description: "End a session by producing a verified handoff prompt for the
  the accepting session. Use when ending a session, context is getting large,
  switching machines, or significant work products need to carry forward.
  Orchestrates audit, assessment, writing, and verification via subagents."
---

## Intent

Produce a verified handoff prompt that captures everything from the current
session -- decisions made, work products, open threads, and scope governance
for the accepting session. The handoff is a self-contained document that a
fresh agent can read and continue from without access to the current
conversation transcript. The accepting session is not necessarily the next
chronological session -- intermediate sessions may intervene.

NOT for mid-session checkpoints (commit and continue). NOT for artifact
harvesting (see `/harvest` skill). NOT for session planning (see `/planning`
skill). Consumed by: any agent ending a session that has produced significant
work.

## When to use

Invoke `/handoff` when ANY of these conditions arise:

- User says `/handoff` or asks to wrap up the session
- Context usage exceeds 60% and significant work remains
- Session has uncommitted decisions, investigations, or work products
  that the accepting session would need
- User is switching machines (work must carry forward via git)
- Session has been running 3+ hours with multiple work streams

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

## Prerequisites

Before starting the handoff workflow:

1. The session must have a scratch directory (per `/scratch` skill). If
   `.scratch/.current-session` does not exist, create the directory first.
2. The agent must know where the project's plan/briefing files live (if
   any). Check for `plans/*/handoff-prompt.md` or `plans/*/planning-brief.*`
   as indicators.
3. If the project uses harvesting (`harvesting/` directory exists), note
   that the SessionEnd hook will handle artifact harvesting -- the handoff
   does not need to wait for it.

## Process

The handoff workflow has 8 steps. Steps 2-6 use subagents to protect
the main agent's context. The main agent orchestrates and verifies.

---

### Step 1: Schwerpunkt declaration

Before producing any artifacts, establish the session's Schwerpunkt for
the handoff itself.

**If the user declared a Schwerpunkt**: Use it.
**If not**: Ask the user:

> "What's the Schwerpunkt for this handoff? What is the single most
> important thing the accepting session must be able to do?"

Suggest an answer based on what the session produced. Examples:
- "Continue implementing the approved decisions from this session"
- "Write the plan file using the brief and investigation products"
- "Fix the bugs found in post-push verification"

The Schwerpunkt for the handoff PROCESS (not the accepting session) is always:
"Produce a verified handoff prompt that captures everything from this
session, enabling a fresh session to continue with clear context."

---

### Step 2: Session state audit

Launch an S2 (Intelligence) subagent to audit the session's state.

**Delegation prompt template:**

```
You are S2 (Intelligence). Your task: audit the current session's state
and produce a structured report.

Read the session scratch directory at: [SESSION_DIR]
Read any other files the session modified (check `git status` and
`git diff --name-only`).

Produce a report with these sections:

1. **Status table** with subsections:
   - 1A. Completed work (shipped to git): item, files changed, commit, status
   - 1B. Decisions made (approved but not yet implemented): decision, blocking?, next action
   - 1C. Work products ready but not approved: item, status
   - 1D. Investigations complete: investigation, key findings, status
   - 1E. Open threads: thread, what is needed

2. **Dependency graph**: which items block which others. Identify
   parallel groups (items that can execute concurrently).

3. **Harvest recommendations**: classify scratch files as either
   harvestable (reusable work) or ephemeral (temp files, logs).

4. **Top 3 to close before session end**: prioritized by urgency
   and blocking potential. Include "NOT now" items with rationale.

5. **Metrics**: scratch file count, findings, decisions, commits,
   incidents filed, open threads.

Write the report to: [SESSION_DIR]/session-state-audit.md

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line
of your response and include the full report content in your response
text instead.
```

**After the subagent completes**: Verify the output file exists. If
WRITE_BLOCKED was returned, write the content yourself from the main
agent (foreground has Write access).

---

### Step 3: Lagebeurteilung (situation assessment)

Launch an S2 subagent to assess whether the handoff is achievable and
propose the accepting session's Schwerpunkt.

**Delegation prompt template:**

```
You are S2 (Intelligence). Your task: assess the feasibility of
producing a handoff prompt for this session and propose the accepting
session's Schwerpunkt.

Read: [SESSION_DIR]/session-state-audit.md

Produce a structured assessment with these sections:

1. **Lagebeurteilung** (situation assessment):
   - 1.1 Forces: what committed work, uncommitted work, approved
     decisions, and intelligence products does this session have?
   - 1.2 Terrain: what is the handoff target? (fresh agent, no
     conversation history, can read files on disk, cannot read this
     transcript)
   - 1.3 Time: session constraints, depleting resources, deadlines
   - 1.4 Logistics: infrastructure state (briefs, plans, manifests,
     configs -- what is current vs stale)
   - 1.5 Assumptions: what is this session assuming that has not been
     verified? For each assumption: what was assumed, who assumed it,
     when, what is the impact if falsified? Surface assumptions
     explicitly -- they are invisible until failure unless tracked.
     Categories to check: artifact persistence (will files survive
     session end?), tool behavior (do subagents have Write access?),
     accepting session state (will the handoff be the next thing
     read?), infrastructure (are referenced tools/configs available?)

2. **Reibung inventory** (friction analysis):
   - Critical friction: what makes this handoff hard?
   - Moderate friction: what adds complexity?
   - Low friction: what is manageable?
   For each item: severity, specific mitigation strategy.

3. **Schwerpunkt verification**:
   - Is the handoff achievable? YES / YES WITH CAVEATS / NO
   - What must happen FIRST? (prerequisites)
   - Where should the handoff be written? (location decision)

4. **Prerequisites checklist**: each prerequisite with status
   (DONE / NOT DONE / NOT NEEDED) and whether it blocks the handoff.

5. **Handoff structure proposal**: recommended sections for the
   handoff prompt, based on the session's content and the Reibung
   analysis.

6. **Recommended Schwerpunkt for the ACCEPTING session**: the single
   most important objective, with a priority sequence. The accepting
   session should first re-assess the running estimate before executing,
   especially if intermediate sessions have occurred since this handoff
   was written.

7. **Exclusion clauses**: what the accepting session must NOT do. Include
   hard exclusions (require formal override to change) and soft
   exclusions (allowed if naturally encountered). Each exclusion
   must have specific rationale.

Write the assessment to: [SESSION_DIR]/schwerpunkt-assessment.md

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line
of your response and include the full assessment content in your
response text instead.
```

**After the subagent completes**: Read the assessment. Verify:
- The Schwerpunkt verdict is YES or YES WITH CAVEATS (if NO, discuss
  with the user before proceeding)
- The exclusion clauses are specific and justified (not vague)
- The priority sequence is actionable

---

### Step 4: Write the handoff prompt

Launch an S3 (Operations) subagent to write the handoff prompt.

**Delegation prompt template:**

```
You are S3 (Operations). Your task: write a handoff prompt that enables
a fresh agent to continue this session's work.

Read these files IN ORDER:
1. [SESSION_DIR]/session-state-audit.md
2. [SESSION_DIR]/schwerpunkt-assessment.md
3. [EXISTING_HANDOFF_PATH] (if one exists -- check plans/*/handoff-prompt.md)
4. Any planning brief referenced in the assessment

The handoff prompt MUST be self-contained: the accepting session's
agent reading ONLY this document must understand what to do, what was
decided, and what NOT to do. Files referenced for depth reading are
supplementary. If intermediate sessions have occurred since this
handoff was written, the accepting session should re-assess the
running estimate before executing the Schwerpunkt.

Use a layered content strategy:
- **Layer 1 (in the handoff)**: everything the accepting session needs
  WITHOUT reading any other file. All decisions, their essential content,
  the Schwerpunkt, exclusions, and the first actions to take.
- **Layer 2 (referenced files)**: full investigation depth, provenance
  research, barrier analyses. Read on demand when entering a work stream.
- **Layer 3 (background)**: planning brief, session transcripts,
  framework references. Read only to trace a decision's origin.

Include a staleness note: "If intermediate sessions have occurred
since this handoff was written, re-assess the running estimate before
executing. The assumptions in this handoff were valid at write time
but may have been falsified by subsequent work."

Required sections (adapt labels to fit the content):

A. **Source of truth**: what file(s) are authoritative for this project's
   decisions. Reading order for the receiving agent.

B. **Intelligence preparation**: files to read before starting work.
   Organized by work stream. Mark which are essential vs supplementary.

C. **Session chain**: table of sessions that produced this state.
   What each session built. Add the current session.

D. **What this session built**: committed work, approved decisions with
   enough detail to implement them, investigation products.

E. **Schwerpunkt for the accepting session**: the single decisive
   objective. Priority sequence. What to do first. The accepting
   session should first re-assess the running estimate, especially
   if intermediate sessions have occurred.

F. **Exclusion clauses**: hard and soft exclusions. FRAGORD requirement
   for out-of-scope work.

G. **Open threads**: each thread classified as READY / BLOCKED / DEFERRED.

H. **New concepts**: any new terminology, frameworks, or patterns
   introduced this session that the receiving agent needs to know.

I. **Delegation updates**: any changes to how subagents should be
   launched, write-failure patterns, operational lessons learned.

J. **Provenance**: version history of this handoff document.

Verify before writing:
- Every approved decision is represented with enough detail to act on
- Every open thread from the session-state-audit appears
- No file path is referenced without being verified to exist on disk
- Section labels do not collide with decision identifiers (e.g., do not
  use "D3" as both a section label and a decision name)
- Cross-references between sections use unambiguous labels

Write the handoff to: [HANDOFF_PATH]

Path pattern: `plans/<briefing-name>/handoff-<session-date>_<session-prefix>.md`
(e.g., `plans/mission-command-briefing/handoff-2026-03-19_Z1IhGrcgGO.md`)

When `.aitools/channel/handoffs/` becomes tracked (after .gitignore
restructuring), the canonical path will be:
`.aitools/channel/handoffs/<session-date>_<session-prefix>.md`

Until then, use `plans/<briefing-name>/handoff-prompt.md` (single
handoff per briefing, updated in place) or the pattern above (one
handoff per session, accumulating).

The handoff MUST be written to a PERMANENT tracked location — never
to session scratch. Scratch directories are deleted by the SessionEnd
hook (harvest-session.sh lines 164-166). A handoff in scratch will
not survive the session it was created in.

SessionStart discovery: when a session starts, it should check for
available handoffs and announce their presence. This enables the
accepting session to discover handoffs without prior knowledge of
their existence.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line
of your response and include the full handoff content in your response
text instead.
```

**After the subagent completes**: Verify the output file exists. Read
the first 30 lines to confirm it has the expected structure. Do NOT
read the entire handoff in the main agent -- it will be verified by the
next step.

---

### Step 5: Verify the handoff

Launch a verifier subagent (ideally in a worktree for isolation) to test
the handoff against 9 criteria.

**Delegation prompt template:**

```
You are a Verifier. Your task: test whether a fresh agent could use this
handoff prompt to continue the session's work.

Read the handoff at: [HANDOFF_PATH]
Read the session state audit at: [SESSION_DIR]/session-state-audit.md
Read the schwerpunkt assessment at: [SESSION_DIR]/schwerpunkt-assessment.md

Test these 9 criteria:

1. **Self-containment**: Can the accepting session's agent understand the
   mission without reading any other file? Are approved decisions clear
   enough to implement without re-deriving? If scratch files were
   deleted, would the inlined content suffice for the first actions?

2. **Reference integrity**: Does every file path referenced in the
   handoff exist on disk? Read each path to verify. Report any broken
   references. CRITICAL: also verify that referenced files will SURVIVE
   the session lifecycle. Files in `.scratch/` are deleted by the
   SessionEnd hook (harvest-session.sh). The handoff itself must NOT
   be in scratch. Referenced scratch files will be harvested to
   `harvesting/` with date-prefixed names — if the handoff references
   scratch paths, note that these paths will change after session end.

3. **Reading order**: Does the reading order build context progressively
   (situation -> findings -> priorities -> background)? Are there
   circular dependencies?

4. **Scope governance**: Is the Schwerpunkt clearly stated? Are exclusion
   clauses specific with rationale? Is there a clear boundary between
   "do now" and "defer"?

5. **Completeness**: Cross-check against the session-state-audit. Is
   every completed item, every approved decision, every open thread
   represented? Are any work products missing?

6. **Consistency**: Does the handoff contradict itself? Do section
   cross-references resolve correctly? If a prior handoff exists, are
   there conflicts between old and new?

7. **Claude Code operational correctness**: Are write-failure signals
   documented? Are subagent context gap mitigations mentioned? Are any
   non-existent CC features assumed?

8. **Ambiguity scan**: Two passes:
   - Pass 1: undefined terms, vague instructions, unclear references
   - Pass 2: terms with multiple meanings, naming collisions
   Rate each finding: High / Medium / Low severity.

9. **Barrier test**: Simulate a fresh agent reading the handoff and
   attempting the first wave of work. At each step: can the agent
   execute? What would cause confusion? Where would it get stuck?

For each criterion, provide: PASS / NEEDS AMENDMENT / FAIL.

If any criterion is NEEDS AMENDMENT or FAIL, list the specific fixes
required with section references.

Overall verdict: READY / NEEDS AMENDMENTS / REWRITE

Write the report to: [SESSION_DIR]/handoff-verification.md

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line
of your response and include the full report content in your response
text instead.
```

**After the subagent completes**: Read the verification report.

- **READY**: Proceed to step 7.
- **NEEDS AMENDMENTS**: Proceed to step 6.
- **REWRITE**: Return to step 4 with the verification findings as
  additional context. This should be rare.

---

### Step 6: Apply amendments

If the verification found issues, launch a subagent to apply the
specific fixes.

**Delegation prompt template:**

```
You are S3 (Operations). Your task: apply amendments to the handoff
prompt based on the verification report.

Read:
1. [HANDOFF_PATH] (the handoff to amend)
2. [SESSION_DIR]/handoff-verification.md (the verification report)

Apply each required amendment from the "Required amendments" section
of the verification report. For each:
1. Read the specific finding
2. Apply the fix
3. Verify the fix does not introduce new ambiguities

Do NOT change content that passed verification. Only fix what the
report identifies.

After applying all amendments, re-check:
- No naming collisions between section labels and decision identifiers
- No broken cross-references introduced by edits
- No content lost during restructuring

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line
of your response and include the amended handoff content in your
response text instead.
```

**After the subagent completes**: If the amendments were minor (label
changes, added references, wording clarifications), proceed to step 7.
If amendments were significant (restructuring, major content additions),
re-run step 5 to verify.

---

### Step 7: Present to user

Show the user a summary of the handoff. Do NOT paste the entire handoff
into the conversation (it may be large). Instead, present:

1. **Where the handoff is**: file path
2. **Schwerpunkt for the accepting session**: the single decisive objective
3. **Exclusion clauses**: what the accepting session must not do (summary)
4. **Verification verdict**: READY (with any notes)
5. **Open items needing user decision**: anything the handoff flagged
   as requiring user input before committing
6. **Uncommitted state**: list of modified/untracked files that will
   be committed

Ask: **"Ready to commit and end the session?"**

If the user wants to review the handoff first, they can read it at the
stated path. If they want changes, return to step 4 or step 6 as
appropriate.

---

### Step 8: Commit and close

If the user approves:

1. **Stage and commit** all session work products:
   - The handoff prompt
   - Any modified governed files (manifest, brief amendments)
   - Scratch files that should be preserved (per the session state audit)
   - Use a descriptive commit message naming the handoff and its
     Schwerpunkt

2. **Run check scripts** per PSO (check-pre-commit, check-pre-push if
   pushing). Do not skip checks even at session end.

3. **Push** if the user requests it (both repos if dotprofile applies).

4. **Report**: state what was committed, what the accepting session
   should read first, and the Schwerpunkt.

---

## Delegation duty

Every subagent launch in this workflow must follow the delegation duty.
The delegating agent (not a fixed "S3" -- any agent that launches a
subagent or produces a handoff) bears this duty. It is recursive per
decision #7: when the delegating agent is itself a subagent, it
inherits the duty from its parent.

1. **Identity**: Name the subagent role (S2, S3, Verifier)
2. **Context**: List every file the subagent must read, in order
3. **Output**: Name the exact file the subagent must write
4. **WRITE_BLOCKED signal**: Every delegation prompt must include the
   WRITE_BLOCKED instruction. Background subagents may be auto-denied
   Write permissions. If this happens, the delegating agent writes the
   content from the subagent's response.
5. **Foreground for file-writing**: If a subagent must write files,
   launch it in the foreground (not `run_in_background`). Background
   subagents cannot get Write approval from the user.
6. **Verify output exists**: After every subagent completes, check that
   the output file was actually written. If not and WRITE_BLOCKED was
   returned, write it from the delegating agent.
7. **Prior results**: What earlier subagents produced that this one
   should know about.
8. **What comes after**: What depends on this subagent's output.
9. **Lifecycle transition awareness**: The delegating agent must verify
   that all artifacts produced by the subagent will survive lifecycle
   transitions. Files in `.scratch/` are deleted by the SessionEnd
   hook. Handoffs, carry-forward state, and any artifact that must
   persist MUST be written to a permanent tracked location (`plans/`,
   `reference/`, `.aitools/channel/`). If the subagent writes to
   scratch, the delegating agent must move the artifact to a permanent
   location before the session ends.

## Handoff quality criteria

A good handoff prompt satisfies all of these:

| Criterion | What it means |
|-----------|---------------|
| **Self-contained** | The accepting session can understand the mission from the handoff alone |
| **Layered** | Essential content is inline; depth is by reference |
| **Scope-governed** | Schwerpunkt declares focus; exclusions prevent drift |
| **Actionable** | First actions are specific and achievable |
| **Unambiguous** | No naming collisions, no undefined terms, no vague instructions |
| **Verified** | Tested against 9 criteria by an independent agent |
| **Complete** | Every decision, thread, and work product is accounted for |
| **Operationally correct** | CC behaviors (write denial, context gap) are documented |
| **Consistent** | Does not contradict itself or prior handoffs |

## Adapting to project context

This skill works in any project. The sections and depth adapt:

**Simple project (few decisions, one work stream)**:
- Steps 2-3 may be done by the main agent (no subagent needed)
- The handoff may be a single page
- Verification may be a quick self-check rather than a full subagent

**Complex project (many decisions, multiple work streams)**:
- Full subagent workflow as described
- Layered content strategy is essential
- Verification must be thorough (naming collisions become likely)

**Project with existing handoff**:
- Step 4 reads the existing handoff and updates it
- The session chain table grows
- Prior content is carried forward or marked as superseded

**Project without plans/ directory**:
- The handoff is written to a permanent tracked location chosen by
  the agent (e.g., `handoff-prompt.md` at repo root, or a new
  `plans/` directory created for this purpose). NEVER to scratch —
  scratch is deleted by the SessionEnd hook.
- The user decides the final location if the agent is unsure

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

- Session planning: `/planning` skill
- Scratch files: `/scratch` skill (includes lifecycle warning)
- Investigation methodology: `/investigate` skill
- Intent writing: `/intent-writing` skill (for intent on new files)
- Delegation evolution: `plans/mission-command-briefing/delegation-evolution.md`
  (how delegation duty was developed through 7 user interventions)
- Handoff exemplar: `plans/mission-command-briefing/handoff-prompt.md`
  (the first handoff produced by this workflow)
- Governed vocabulary: `/glossary` skill (terms: handoff, accepting
  session, delegating agent, lifecycle transition, assumption,
  Schwerpunkt, Lagebeurteilung, Reibung, Mitdenken, Auftrag)
