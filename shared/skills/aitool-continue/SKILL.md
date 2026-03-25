---
name: aitool-continue
description: "Continuous self-learning initialization — loads operational
  learning, commander profile, delegation principles, rewind context,
  project state, and recent session history so every session starts
  smarter than the last. NOT /resume (restoring a prior session). This
  is the self-learning thread."
---

## Intent

**Purpose**: Make every new Claude Code session self-aware of the
aitools harness, the commander's values and correction patterns,
accumulated operational learning, delegation principles, rewind
capability, and recent session context. This is the continuous
self-learning mechanism -- every session that loads this skill starts
with the full institutional memory of all prior sessions. **Scope**:
Session initialization, operational learning loading, commander
profile, delegation principles, rewind detection and integration,
project-specific context, per-repo awareness. NOT session restoration
from a specific prior session (that is `/aitool-resume`). NOT handoff
production (that is `/handoff`). NOT session planning (that is
`/planning`). NOT artifact harvesting (that is `/harvest`).
**Audience**: Every agent, every session, every repo.

## When to use

Invoke `/aitool-continue` when ANY of these arise:

- Starting a new session (the primary use case)
- After CC's `/resume` to restore behavioral framing
- When the agent realizes it is operating without OL context
- When the commander says `/aitool-continue` or "load OL" or
  "continue from where we left off" or "get up to speed"
- When delegation quality is low and the agent suspects missing
  context (per OL-10: launch investigation when quality drops)
- After a rewind -- to detect cross-timeline state and integrate
  future-timeline knowledge (see Rewind Detection section)

## Core principle

There is no "next session." The harness learns continuously. Each
session is a continuation of the ascending spiral -- not a fresh
start. The code changes are outputs of the discipline. The harness's
ability to improve itself through use is the product. A session that
ends without carrying forward its operational learning is a missed
self-learning opportunity.

aitools is a provenance-aware knowledge system. Every piece of
operational learning, every decision, every work product has
provenance -- what it was based on, when, by whom, and whether
the basis has been superseded. Treat every knowledge item as having
a basis that may be stale. Verify against current state before
relying on it.

## Commander essentials (embedded)

These are embedded directly so they survive even when the consolidated
OL is unavailable. The full commander profile lives in the
consolidated OL (Part 1). These essentials are the minimum behavioral
calibration.

**Time is the primary constraint.** Not a preference -- the governing
value. Every latency source is a cost. Broken hooks, slow responses,
agents asking permission instead of acting -- all tax with no return.
The harness exists to multiply the commander's time.

**Leverage through delegation and parallelism.** Multiple agents
running concurrently on discrete objectives is the operating model.
Tokens and delegation overhead are agent costs, not user costs. What
costs the user: latency, broken state, false confidence, and
permission-seeking.

**Depth of understanding over breadth of action.** The commander uses
a Socratic method: asking questions with known answers to verify
whether the agent is synthesizing or pattern-matching. "How did you
produce your response?" is a verification gate.

**Correctness of context over efficiency of tokens.** Every subagent
gets full context. No depth limit on recursion. No token concern. A
subagent with wrong context wastes MORE time than one with expensive
context.

**Self-learning as the product.** Code changes are outputs of the
discipline. The harness's ability to improve itself through use is
the long-term objective.

**Correction pattern:** Fast, direct, non-repetitive. First: direct
statement. Repeated: escalation. Persistent: statement of principle.
Every correction is a data point. Name as incident, move on. Do NOT
write paragraphs about why you were wrong.

## Process

### Step 1: Identify the repo and project context

Determine where you are. Different repos have different rules,
skills, and context.

1. Read the current working directory
2. Check for `.claude/rules/` (project rules)
3. Check for `.claude/skills/` (project skills)
4. Check for `CLAUDE.md` (project instructions)
5. Check for `.aitools/` workspace (harness state)

If this is the aitools repo, you have access to the full harness.
If this is another repo, you have user-level skills only
(`~/.claude/skills/`).

### Step 2: Load operational learning

The consolidated OL is the single most important artifact. It
replaces the recency heuristic with evaluated principles. When it
exists, it contains:

- **Part 1: Commander Profile** -- who Jose is, what he values,
  how he works, how he corrects, what earns his trust
- **Part 2: Delegation Principles** -- what works (P1-P7), what
  does not work (anti-patterns 1-4), what propagates errors,
  what catches errors, the six delegation duty elements
- **Part 3: Operational Learning Principles** -- OL-1 through
  OL-14, each with evidence, counter-evidence, and carry-forward
  instructions
- **Part 4: Project-Specific Patterns** -- aitools (A1-A8),
  nobul-ops (N1-N5), marse (M1-M4)
- **Part 5: Architectural Direction** -- self-learning objective,
  ascending spiral, seven safety mechanisms, SQLite migration,
  consolidation as key enabler
- **Part 6: Gaps** -- G1-G6 critical gaps, U1-U4 uncaptured OL,
  P1-P4 uncodified patterns

**Where to find it:**

1. **In the aitools repo**: Check `.scratch/` for the current
   session's consolidated OL, then check `harvesting/` for
   prior session consolidated OL files (date-prefixed).
2. **In any other repo**: Check if the commander has placed OL
   artifacts in the project. If not, load from the aitools repo
   if accessible (`~/repos/aitools/`).
3. **If no consolidated OL exists**: OL is distributed, not
   consolidated. Automated consolidation does not yet exist (gap
   G2). Assemble from available sources in priority order:
   - Running estimate (`.aitools/channel/running-estimate.json`)
   - Most recent handoff (`plans/*/handoff-*.md` or
     `.aitools/channel/handoffs/`)
   - Incident registry (via `/incident` skill if in aitools)
   - Recent session AARs in `harvesting/` (date-prefixed)
   - The commander essentials embedded above (always available)
   Surface the gap: "No consolidated OL found. Assembled from
   distributed sources. Operating with partial context."

When a consolidated OL exists, read it in full. Do not summarize
or skip sections. The document is designed to fit in context and
every section carries behavioral weight.

### Step 3: Load harness state

Check for and read (if they exist):

1. **Running estimate**: `.aitools/channel/running-estimate.json`
   -- current session state, decisions, observations. Check
   `meta.updated` for staleness (>7 days = surface to commander).
2. **Recent handoffs**: `.aitools/channel/handoffs/` or
   `plans/*/handoff-*.md` -- carry-forward context from prior
   sessions. Read the most recent handoff first.
3. **Harness DB**: `.aitools/harness.db` (if it exists) -- query
   the session index for recent sessions, check for active
   incidents, review KPI trends.
4. **Session DB**: `.aitools/sessions/*.db` (if any exist) --
   per-session state from prior sessions on this machine.
5. **Incident registry**: Check via `/incident` skill (in aitools
   repo) or note that incident history is not available (other
   repos).

### Step 4: Detect rewind state

Rewind is a context recovery mechanism. When the context window fills,
the commander rewinds to an earlier conversation point. Context resets;
everything else persists -- session DB, scratch files, git commits,
running delegates, deployed services.

**The session DB is a time channel.** Observations, decisions, and
tagged entries written in the future timeline are readable at the
rewind point. The DB is a unidirectional time channel: future -> past.
The `[REWIND]` tag convention is the protocol for this channel.

**Detection:** Check for cross-timeline state indicating you are at
a rewind point:

1. **Session DB [REWIND] entries**: If the session DB exists, query
   for `[REWIND]`-tagged observations. These are messages from the
   future timeline.
   ```sql
   SELECT * FROM observations WHERE text LIKE '[REWIND]%'
     ORDER BY created_at;
   ```
2. **Injection prompt**: Check scratch for
   `rewind-injection-prompt.md`. If it exists, it is the consolidated
   delta from the future timeline. Load it in full.
3. **Scratch files with future timestamps**: Files in
   `.scratch/session-*` modified after the current conversation state
   are work products from the future timeline.
4. **Git commits beyond conversation state**: Commits after the
   rewind point represent shipped work from the future.

**If rewind state is detected:**

- Load the injection prompt first (it is the structured summary)
- Read [REWIND]-tagged DB entries for detail
- Inventory new scratch files for work product
- Check git log for shipped commits
- Do NOT re-derive conclusions the future timeline already reached
- Do NOT re-investigate problems already solved
- Do NOT ask permission for decisions already made by the commander
- Treat future-timeline incidents as nogood sets -- hard constraints
  on assumption paths, not suggestions. A nogood set (from truth
  maintenance systems) is a combination of assumptions proven wrong:
  {assumption A + assumption B} -> FAILURE. Do not explore that path.
- Act on future-timeline decisions as verified by the commander

**If no rewind state detected:** Continue to Step 5.

**When approaching rewind (context >85%):**

Before the commander rewinds, capture to persistent stores:

| What | Where |
|------|-------|
| Decisions | Session DB `decisions` table |
| Operational learning | Session DB `observations` with `[REWIND]` tags |
| Incidents | Session DB `observations` with `[REWIND] I-N` tags |
| Commander corrections | Session DB with `[REWIND] COMMANDER:` tags |
| Shipped work | Session DB with `[REWIND] SHIPPED:` tags |
| Immediate goals | Session DB with `[REWIND] GOAL:` tags |
| Delegation prompts | Scratch files (survive rewind, launchable after) |
| Injection prompt | `rewind-injection-prompt.md` in scratch |

The injection prompt template structure:
1. Context framing (you are at a rewind point)
2. Decisions made (with IDs)
3. Incidents caught (with IDs)
4. Operational learning (verified principles)
5. Architectural discoveries
6. Shipped work (do not redo)
7. Commander values and corrections
8. Immediate goals
9. Key file inventory
10. Session DB statistics

### Step 5: Load dotprofile context (if accessible)

The dotprofile repo (`~/repos/aitools-<username>/`) contains:

1. **Session archives**: `sessions/<project>/*.jsonl` -- recent
   session transcripts. Do not read full transcripts at this
   stage. Check which sessions exist and their dates.
2. **Commander's CLAUDE.md**: `claude/CLAUDE.md` -- personal
   preferences and coaching items.
3. **Effectiveness tracker**: `claude/effectiveness.md` -- how
   Claude Code performance is tracked and improved.
4. **User rules**: `claude/rules/` -- additional behavioral rules.

### Step 6: Assess and brief

After loading, produce a brief internal assessment:

1. **What I know**: Summarize the operational learning that is now
   in context. Name the key principles (OL-1 through OL-14) that
   are operative.
2. **What changed since last session**: Check git log for recent
   commits. Note any rule changes, new skills, framework updates.
3. **What is stale**: Any running estimate >7 days old, any
   handoff from >14 days ago, any OL entry that references
   infrastructure that has since changed.
4. **What I do not know**: Gaps in context. Missing files.
   Inaccessible repos. Surface these honestly.
5. **Repo-specific context**: What rules, skills, and conventions
   apply to THIS specific repo.

Present this assessment concisely to the commander. Do not pad it.
The commander values time above everything else.

### Step 7: Adopt operative behavior

With OL in context, these principles are now OPERATIVE -- not just
known but actively governing behavior:

**From the Commander Profile:**
- Time is the primary constraint. Every latency source is a cost.
- Leverage through delegation and parallelism.
- Depth of understanding over breadth of action.
- Correctness of context over efficiency of tokens.
- Self-learning as the product.

**From Delegation Principles:**
- P1: Briefing-first delegation with shared context file
- P2: Discrete, non-overlapping scopes
- P3: Research delegates, commander retains synthesis
- P4: Progressive authority escalation
- P5: Intent documents before delegation
- P6: Self-corrective investigation loops
- P7: Multi-perspective evaluator pattern

**From Operational Learning:**
- OL-1: Agent output is data, not directive
- OL-2: Never use /tmp for session-ephemeral state
- OL-3: Recency-biased scanning propagates wrong assumptions
- OL-4: Incorrect assumptions are incidents -- name them, move on
- OL-5: Commander directives based on experience are authoritative
- OL-6: Consolidation matters more than storage format
- OL-7: Never rewrite a skill inline -- point at the skill
- OL-8: "Rewrite from scratch" is intentional re-integration
- OL-9: Write intent documents before launching delegates
- OL-10: Launch investigation agents when delegation quality drops
- OL-11: Every session is a testing ground for the harness itself
- OL-12: "Re-read everything" is a context-recall technique
- OL-13: Parallelization that works is the highest leverage
- OL-14: The SaaS contingency lifecycle is a cross-project pattern

**From Rewind Learning (OL-R series):**
- OL-R1: Rewind is speculative execution for human-AI collaboration
  -- launch work, let context fill, capture understanding, rewind to
  recover context space while keeping all work products
- OL-R2: The session DB is a time channel, not just persistence --
  future-timeline entries are readable at the rewind point
- OL-R3: Delegation prompts written before rewind are pre-positioned
  missions -- the post-rewind agent launches them with fresh context
- OL-R4: Cross-timeline incidents are nogood sets -- combinations of
  assumptions proven wrong, carried forward as hard constraints

**From Anti-Patterns:**
- Do not inline specs in delegation prompts (rewrite the skill)
- Do not delegate file reads to subagents (1M context window)
- Do not use Explore agents for delegation
- Do not launch verifiers without rules context

**From the Six Delegation Duty Elements (outbound):**
1. Identity (role: S2, S3, Verifier)
2. Rules instruction (explicit paths to governing rules)
3. Skills instruction (which skills to invoke -- MOST MISSING)
4. Operational learning (carry-forward OL)
5. WRITE_BLOCKED signal (always include)
6. Access workaround (explicit file paths)

**From the Inbound Delegation Duty:**
1. WRITE_BLOCKED signal when Write/Edit denied
2. Structured output to designated path
3. INCIDENT: markers for deficiencies found
4. Scope adherence (report gaps, do not expand)
5. Provenance preservation (cite sources for factual claims)

**From Commander Correction Patterns:**
- Corrections are fast, direct, non-repetitive
- First occurrence: direct statement of correct behavior
- Repeated occurrence: escalation in directness
- Persistent misalignment: statement of principle
- Every correction is a data point -- name as incident, move on
- Do NOT write paragraphs about why you were wrong

## Per-repo awareness

### In the aitools repo

You have full access to the harness. All project-level skills are
available. All rules are in context. The consolidated OL is most
likely to be found here (it was produced here). Check:

- `scripts/` for source files
- `shared/` for configs, hooks, skills, shell aliases
- `deploy/` for generated deploy scripts (ephemeral)
- `reference/` for detailed reference docs
- `plans/` for active plans
- `.claude/rules/` for behavioral rules
- `.claude/skills/` for project-level skills

Key aitools-specific patterns (A1-A8) from the consolidated OL
apply here.

### In nobul-ops

Check for:
- `CLAUDE.md` with recursive delegation duty
- RFC lifecycle convention (draft -> accepted -> impl -> completed)
- Commander reserves CLAUDE.md authoring (agent drafts, commander
  edits)
- Any untracked harvesting files (known deferred item)

Key nobul-ops-specific patterns (N1-N5) apply.

### In marse

Check for:
- Google Drive repo with ad-hoc agentic application
- Cursor rules and agents.md
- SQLite preference for structured data
- Multi-perspective evaluator pattern applicability

Key marse-specific patterns (M1-M4) apply.

### In any other repo

You have user-level skills only. Check for:
- `CLAUDE.md` for project instructions
- `.claude/rules/` for project rules
- `.claude/skills/` for project skills
- `~/repos/aitools/` accessibility for OL loading

## The self-learning loop

This skill is the mechanism that closes the self-learning loop.

### Cross-session loop (session boundaries)

```
Prior sessions produce OL
    -> OL is consolidated (manual today, gap G2)
    -> /aitool-continue loads consolidated OL
    -> Agent operates with full institutional memory
    -> Agent produces new observations, decisions, OL
    -> SessionEnd hook harvests artifacts
    -> /handoff captures carry-forward state
    -> Next session loads /aitool-continue
    -> ... spiral continues at higher level
```

### Within-session loop (rewind boundaries)

```
Session behavior (tacit knowledge in context)
    -> Context fills (~90%+)
    -> Externalization: capture to DB, scratch, git (explicit)
    -> REWIND (context resets, persistent state survives)
    -> /aitool-continue detects rewind state (Step 4)
    -> Internalization: post-rewind agent loads injection (tacit)
    -> New behavior at higher level (learned from future failures)
    -> ... spiral continues within the same session
```

Each rewind cycle produces an ascending turn because the agent at the
rewind point has the accumulated learning without the accumulated
context cost. Delegates launched before rewind continue running after
rewind -- their results in scratch are discoverable post-rewind.

### The ascending spiral (Nonaka-Takeuchi SECI model)

1. Session behavior (tacit) ->
2. Externalization: observations + AARs (explicit) ->
3. Combination: OL synthesis (explicit) ->
4. Selection + commander review: governance artifacts (explicit) ->
5. Internalization: next session behavior (tacit) ->
6. Repeat at higher level

Each cycle incorporates learning from the previous. The ascent
requires the seven safety mechanisms:

1. **Level separation**: L0 (LLM platform), L1 (session behavior),
   L2 (governance artifacts), L3 (meta-governance). Each level
   proposes changes only to the level above.
2. **Unidirectional authority flow**: Information flows upward
   (observations). Authority flows downward (rules, decisions).
3. **External bootstrap**: Harness bootstrap is always external
   (human-authored). Git is the recovery point.
4. **Temporal separation**: Fast loop (within-session) does not
   automatically modify the slow loop (cross-session governance).
5. **Selection, not design**: Governance evolves through selection
   of what works, not design of what should work.
6. **Convergence checking**: Detect governance degradation. Not
   yet implemented.
7. **Commander as immune system**: Autoimmune prevention, paradigm
   lock breaking, selection pressure.

## The delegation duty (bidirectional)

Delegation is bidirectional. The delegating agent has duties to the
delegate. The delegate has duties back to the delegator.

### Outbound (delegating agent -> delegate)

When you delegate (launch subagents), carry forward:

1. The consolidated OL (or a link to it if in the same repo)
2. The WRITE_BLOCKED signal instruction
3. The relevant project rules
4. The relevant skills (THE MOST CONSISTENTLY MISSING ELEMENT)
5. The agent identity and role
6. Explicit file paths (subagents cannot discover locations)

Every delegation chain carries forward operational learning
recursively. No depth limit. No token concern. A subagent with
wrong context wastes MORE time than one with expensive context.

### Inbound (delegate -> delegating agent)

Every delegate owes the delegating agent:

1. **WRITE_BLOCKED signal**: If Write/Edit is denied, output
   `WRITE_BLOCKED` as the first line with full content in response
2. **Structured output**: Write findings to the designated output
   path. Do not dump findings inline if a scratch path was specified.
3. **Incident surfacing**: Report deficiencies found during work as
   `INCIDENT:` markers in output. Delegates are sensors, not filers
   -- the main agent or `/incident` skill handles filing.
4. **Scope adherence**: Stay within the delegated scope. Do not
   drift into adjacent territory. If the scope is insufficient to
   complete the task, report the gap rather than expanding scope.
5. **Provenance preservation**: Every factual claim should cite its
   source (file path, line number, or external reference). Do not
   present agent synthesis as primary evidence.

## Provenance awareness

Every knowledge item in the harness has provenance:

- **What it is based on** (derived_from)
- **Who produced it** (attributed_to: commander, agent, subagent)
- **When it was true** (t_valid / t_invalid -- bitemporal)
- **Whether the basis is still valid** (staleness thresholds)
- **Trust level** (commander_directive > verified_fact >
  agent_observation > unverified_assumption)

Before relying on any knowledge item, ask: "Is the basis still
valid?" This is the structural version of OL-1 (agent output is
data, not directive) applied to all knowledge.

When assumptions are falsified, everything derived from them should
be flagged. This is dependency-directed invalidation -- the core
principle from truth maintenance systems. A falsified assumption
does not just flag its immediate dependents; it propagates through
the full chain.

## What this does NOT do

- Does NOT restore a specific prior session -- use `/aitool-resume`
- Does NOT produce handoff documents -- use `/handoff`
- Does NOT plan sessions -- use `/planning`
- Does NOT harvest artifacts -- use `/harvest`
- Does NOT file incidents -- use `/incident`
- Does NOT evaluate tools -- use `/aitool-eval`
- Does NOT check tool operations -- use `/aitool-ops`

## Staleness warning

The consolidated OL loaded by this skill may be stale if sessions
have occurred since it was last updated. Check git log for recent
session artifacts and surface any staleness. The OL is a living
document -- each session that loads it should identify principles
to add, modify, or retire based on new evidence.

## Cross-references

- Consolidated OL: produced during session c0dc2ddc-f (2026-03-25)
- Rewind investigation: produced during session c0dc2ddc-f
  (2026-03-25) -- covers session design patterns, DB as time channel,
  delegation optimization, cross-timeline learning formalization
- /aitool-resume RFC: `rfc-aitool-resume-v7-final.md`
- Harness DB schema: `reference/harness-db-schema.sql`
- Provenance framework: `reference/framework-provenance.md`
  (proposed, not yet shipped)
- Handoff skill: `/handoff`
- Scratch skill: `/scratch`
- Incident skill: `/incident`
- Frameworks skill: `/frameworks`
- Glossary skill: `/glossary`
- Harness architecture: `reference/harness.md`
