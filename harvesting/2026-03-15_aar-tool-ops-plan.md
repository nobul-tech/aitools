# After Action Review: Tool-Ops Framework Planning Session

**Session**: `84280c8b-74e9-4154-8f74-a2d3acc7690a`
**Date**: 2026-03-15, 20:08 UTC - 22:57 UTC (2 hours 49 minutes)
**Slug**: gleaming-cooking-unicorn
**Plan file produced**: `~/.claude/plans/gleaming-cooking-unicorn.md`
**Branch**: main

---

## 1. Executive Summary

What began as a quick verification ("can you confirm the claude-code-guide
deny rule works?") became the most architecturally significant session in
the aitools project. A broken deny rule led to a full incident investigation,
which revealed scattered operational knowledge about Claude Code, which
prompted the user to ask for a framework to capture it, which evolved into
the Tool Operations (tool-ops) framework -- a new governance layer for
per-tool operational metadata. Along the way, the user drove a merge of
the gap and incident tracking systems, discovered military doctrine
parallels to the delegation protocol being designed, and pushed the plan
through seven full rewrites to eliminate ambiguity. The session produced
working code (deny fix, PreToolUse hook with corrective injection, test
suite), three subagent investigations, and a plan file that introduces
concepts new to the harness: execution protocols, delegation duty,
identity briefings, and evidence-based governance mode promotion.

---

## 2. Timeline / Arc of the Session

### Phase 1: Verification and Incident (20:08 - 20:16, ~8 min)

**L3** [20:08] User asks to verify that the `claude-code-guide` deny rule
works. This is a simple verification of a fix shipped in a prior session
(commit `46c93b3`).

**L29** [20:09] Agent tests by actually invoking the denied subagent. It
runs successfully. The deny rule is broken.

**L37** [20:09] Agent identifies the likely cause: pattern mismatch.
`Agent(Claude Code Guide)` (display name) vs `claude-code-guide`
(internal identifier).

**L51-54** [20:09] User says "use your investigate skill" -- escalating
from quick verification to structured incident response.

**L57-170** [20:10-20:13] Full investigation with chrome-devtools reading
the official CC docs, upstream issue research (GH #25000, #6699), and
an Explore subagent for pattern syntax research. Key finding: the hooks
docs explicitly state "SubagentStart cannot block subagent creation" but
"PreToolUse on Agent CAN deny the tool call."

**L178-189** [20:15-20:16] RCA presented. Three options: A (fix pattern),
B (add hook), C (both). User approves Option C.

### Phase 2: Implementation and Testing (20:17 - 20:29, ~12 min)

**L212-354** [20:17-20:20] Three-batch implementation: deny pattern fix
(2 files), hook creation + deployment scripts (3 files across sh/ps1),
live deployment and testing. The PreToolUse hook blocks the subagent
mid-session -- proven live.

**L399-453** [20:21-20:23] GH issue #34730 updated with full findings.
User requests the original "I know, right?" exchange be included -- agent
audits the prior session transcript (a different JSONL file) and finds
the exact exchange where the agent admitted "an AI agent hallucinated a
schema, another AI agent trusted it without checking, shipped it to
production, broke every hook on the user's machine."

**L458-517** [20:26-20:29] User asks two forward-looking questions:
(1) Can we incorporate hook testing into a framework? (2) Can we inject
corrective context instead of just blocking? Agent builds a mock-JSON-pipe
test pattern (8 test cases, runs in milliseconds, no API calls) and
upgrades the hook from exit-code-2 blocking to JSON-output deny with
rich `permissionDecisionReason` containing the correct doc URLs and
schema quick reference.

### Phase 3: Framework Vision (20:33 - 20:54, ~21 min)

**L522** [20:33] The pivotal moment. User says:

> "so claude code is a tool we manage. we need an aitools-claude
> framework or something like it that captures everything we've
> learned: how to read the docs, how to test settings, the
> ambiguities that are undocumented."

And immediately (L523) interrupts themselves, then adds (L525):

> "im not convinced aitools-claude is the right name btw"

The user loaded the `/frameworks` and `/tool-registry` skills to give
the agent context (L530, L542).

**L622** [20:38] Agent delivers the synthesis: "What it IS: the knowledge
gap between 'what the docs say' and 'what actually happens in production.'
SRE calls this a runbook." Proposes "Tool Operations" as the name, with
five categories of operational knowledge per tool, and audits the 4
existing CC reference files that are fragments of what tool-ops would
govern.

**L627-633** [20:38-20:41] Meanwhile, a subagent investigation returns
with a critical finding: the `/tool-registry` skill references a phantom
file (`tool-registry.json`) that doesn't exist. The actual data lives in
`tool-registry.md`. User reacts:

> "wtf. maybe we never got to that."

Agent audits prior sessions and confirms: the migration was planned
(incident #21) but never started. The skill was written to the
target state, not the current state.

**L633** [20:41] User names the framework:

> "i love what you recommended. lets call it tool-ops for short"

**L700** [20:43] Agent suggests stopping and committing. User overrides:

> "nah lets keep going"

### Phase 4: Design Deep-Dive (20:51 - 21:21, ~30 min)

**L713** [20:51] User delivers a dense design prompt touching: per-platform
evolution, one framework for all tools, three-layer fit, hook injection
patterns, why glossary/registry hooks never fire, whether a JSON file is
needed, and the MANIFEST.json concept from a prior session. Two subagent
investigations launch in parallel (glossary hook, MANIFEST search).

**L732-748** [20:53-20:54] Both investigations return. The glossary hook
finding is architecturally important: "prevention (the rule in context)
is effective, so detection (the hook) stays dormant." The MANIFEST search
finds two concepts: `harvest-manifest.json` and the cascade manifest from
the managed-content-cascade plan.

**L737-742** [20:53] User says "lets start by defining its intent." Agent
loads the `/intent-writing` skill and drafts a three-part JSON intent.

**L752** [20:58] User pushes back on three design points, demanding the
agent ground recommendations in specific frameworks rather than gut
decisions. This produces the session's most framework-dense response
(L754), citing:

- SRE operational readiness reviews (Google SRE book, Ch. 32)
- Hook-rollout observe-then-enforce (internal framework)
- Managed-file-deployment state machine (internal framework)
- Gap governance / PDCA (quality management)
- Argyris' double-loop learning / DTCC cycle (internal framework)
- Lean pull systems (Ohno, Toyota Production System)
- ITIL incident/problem separation

**L759** [21:03] User makes two design decisions:
1. Build in audit/active switch from day one
2. Merge gaps and incidents -- "who cares what they are? lets just call
   them incidents" (L784)

**L766-805** [21:04-21:11] Rapid-fire design refinements: SessionEnd
hooks for enforcement (L766), separate hook for tool-ops (L774), hooks
can't use skills (L779 -- "oh fuck"), per-tool per-capability governance
mode switches (L798), KPIs as a switch (L805).

**L810** [21:11] User: "cool, looks good, lets get the intent right,
and then fold all of this into a single plan"

**L820-857** [21:14-21:21] Final design refinements: redundancy audit
against tool-registry/tool-eval, testing patterns in the ops reference
file, verification specs as actionable JSON fields (contract testing
from Pact framework), and the sixth deploy mode switch for verifications.

### Phase 5: Plan Writing (21:21 - 21:41, ~20 min)

**L857** [21:21] User: "love it, do we have enough to remove all ambiguity
and enter plan mode?"

Agent enters plan mode, launches three pre-plan investigations in parallel
(framework adoption pattern, incidents rename blast radius, cascade
manifest connection), then a Plan subagent to design the implementation.

**L1033** [21:31] First plan draft written to
`~/.claude/plans/gleaming-cooking-unicorn.md`. 8 batches across two major
efforts.

**L1048** [21:32] Agent catches a framing error where the plan implies CC
is the harness rather than a tool within it. Self-corrects: "aitools is
the harness platform. Claude Code is a managed tool within it."

**L1066-1094** [21:38-21:41] Agent audits the plan for governed term
misuse. Finds 6 ambiguities: "Trigger" (governed DTCC term used loosely),
"deploy mode" (conflates with managed-file-deployment), "absorbed"
(unclear action), "pattern" (two senses), "promotion" (two contexts).
Rewrites from scratch.

### Phase 6: Execution Protocol Refinement (22:02 - 22:25, ~23 min)

**L1103-1111** [22:02-22:03] Agent proposes adding an "execution protocol"
to the plan. User interrupts:

> "execution protocol is the right term, but it does more than what you
> summarized. re-read my prompt and... respond back to me with a revised
> message"

**L1115** [22:05] User catches an undefined term:

> "you used a term there we havent defined. wtf is bootstrap? re-read
> your last prompt, remove ambiguities from instructions to executing
> agent, do multiple passes of this and come back to me before rewriting
> the plan"

Agent does 4 explicit passes identifying and removing ambiguous terms
("bootstrap", "calibrate verbosity", "more weight").

**L1122** [22:08] User refines instruction 2 (intent writing):

> "i dont think our skill is good enough yet. i think my explicit
> instructions are better. it should look at the skill itself, but it
> should not invoke it."

**L1129** [22:10] User adds a "known state" concept:

> "we should note the bad state of tool-registry.md and
> tool-versions.json and reference our conversation"

**L1135** [22:12] User generalizes: "audit our recent conversations and
plans for similar types of annotations to the known state."

**L1187** [22:19] The delegation duty is born:

> "include instructions for the executing agents that, before they
> delegate work to a subagents, they need to review and update the
> instructions passed on what has been accomplished thus far, and if
> we have deviated from the plan, and if other things have surfaced.
> basically, all executing agents have a duty to improve and refine the
> prompt they are delegating."

**L1194** [22:21] User: "thats beautiful. now re-read our plan, line by
line, and re-write it from scratch applying that everywhere"

**L1203** [22:24] Third full rewrite produced.

### Phase 7: Military Doctrine and Final Passes (22:25 - 22:57, ~32 min)

**L1211-1224** [22:25-22:26] Agent researches military planning doctrine
via WebSearch and identifies three parallel frameworks: Mission Command
(Auftragstaktik), OPORD/WARNORD/FRAGORD, and Backbrief.

**L1229** [22:28] User: "do one more pass... re-read it, line by line, and
re-write it from scratch"

**L1236** [22:29] User adds a constraint:

> "remember the limitations and capabilities of our harness and the need
> to adapt these frameworks to those constraints"

**L1238** [22:33] Fourth rewrite. Execution protocol step 6 now documents
five harness constraints that shape how military mission command concepts
apply: sub-agents don't persist, don't inherit rules, no mid-execution
updates, no peer communication, verification happens after (not before)
execution.

**L1271** [22:47] User adds identity duty:

> "its a duty on the delegating agent to ensure each subagent knows its
> identity. it should do its best to include an identity profile for the
> subagent."

**L1273** [22:50] Fifth rewrite with identity briefings per batch.

**L1283** [22:55] User approves and requests a final rewrite to embed
"carry awareness" into the plan's opening. Sixth rewrite begins.

**L1294-1316** [22:56-22:57] Final edits. Three reinforcement points:
opening addressee, protocol opening, batch plan intro. Session ends with
the user interrupting the response (L1319), likely to start the execution
session.

---

## 3. Key Decisions and Turning Points

### Decision 1: Investigate, Don't Just Fix (L51)
**Who**: User
**What**: Escalated from "fix the deny pattern" to "use your investigate
skill" -- triggering structured RCA.
**Impact**: Uncovered that even the correct pattern might not work (GH #25000),
leading to the PreToolUse hook as structural fix.

### Decision 2: Defense in Depth (L189)
**Who**: User (approved agent's recommendation)
**What**: Option C -- both deny pattern fix AND hook.
**Impact**: Established the principle that shaped the entire tool-ops
framework: multiple layers, each catching what the other misses.

### Decision 3: Corrective Injection Over Simple Block (L458 Q2)
**Who**: User (question), Agent (design)
**What**: Instead of just blocking the buggy subagent, inject the correct
answer into `permissionDecisionReason`.
**Impact**: Created the "block wrong approach, inject correct approach"
pattern that became the cornerstone of tool-ops hook design.

### Decision 4: Framework, Not Ad Hoc (L522)
**Who**: User
**What**: Recognized scattered operational knowledge as a systemic problem
requiring a framework, not just another reference file.
**Impact**: Triggered the entire tool-ops design effort.

### Decision 5: "tool-ops" Naming (L633)
**Who**: User
**What**: Rejected "aitools-claude" as too narrow. Named it "tool-ops"
after the agent proposed "Tool Operations."
**Impact**: The name signals the framework generalizes to all managed
tools, not just CC.

### Decision 6: Merge Gaps and Incidents (L784)
**Who**: User
**What**: "who cares what they are? lets just call them incidents"
**Impact**: Simplified the governance model by eliminating a false
distinction. One registry, one lifecycle, one skill.

### Decision 7: Per-Tool Per-Capability Switches (L793-798)
**Who**: User (prompted by agent's hook insight)
**What**: Governance modes are granular -- each tool, each capability
(denyRules, hooks, contextInjection, kpis, verifications) can be at
"audit" or "active" independently.
**Impact**: Evidence-based promotion becomes possible. The SessionEnd
hook tracks drift per capability and promotes when evidence says ready.

### Decision 8: Delegation Duty (L1187)
**Who**: User
**What**: Formalized that every delegating agent must brief its sub-agents
with accumulated context, deviations from plan, and situational awareness.
**Impact**: Introduced a new harness concept that transcends this plan --
applies to all future multi-batch work.

### Decision 9: Identity Briefings (L1271)
**Who**: User
**What**: Each sub-agent must be told who it is, what role it plays, and
how it fits the larger effort.
**Impact**: Addresses the sub-agent context gap at the identity level,
not just the information level.

### Decision 10: Harness Constraint Adaptation (L1236)
**Who**: User
**What**: Military doctrine is useful inspiration but must be adapted to
harness realities (no persistence, no peer communication, no mid-execution
updates).
**Impact**: Prevented cargo-culting of military terms and forced the agent
to document exactly where each doctrine applies and where it breaks down.

---

## 4. Framework Adoption Journey

### Frameworks Referenced and How They Were Used

**Internal (already in the harness):**

| Framework | How It Was Applied |
|-----------|-------------------|
| Hook-rollout (release engineering) | Observe-then-enforce model became audit/active governance modes |
| Managed-file-deployment (config mgmt) | Discover-validate-deploy progression supported audit-first design |
| Gap governance (PDCA) | Surfacing duty model applied to tool-ops entry triggers |
| Framework adoption (Argyris double-loop) | DTCC cycle supported demand-driven (not speculative) ops entries |
| Three-layer governance (prevention/detection/audit) | Structured the entire tool-ops enforcement model |

**External (researched and adapted):**

| Framework | Source | What Was Adopted | What Was Rejected/Modified |
|-----------|--------|------------------|---------------------------|
| SRE Operational Readiness Reviews | Google SRE Book Ch. 32 | "Checklists before automation" became audit-before-active | Full ORR process too heavyweight |
| Lean Pull Systems | Ohno, Toyota Production System | Demand-driven entries, not forecasted | Manufacturing metaphors |
| ITIL Incident/Problem Management | ITIL v3/v4 | Incident lifecycle fields (RCA, corrective action) | Incident/problem separation rejected -- merged into single concept |
| Contract Testing / Pact | Consumer-driven contracts | Verification specs as actionable JSON defining integration contracts | Full contract broker pattern |
| Mission Command (Auftragstaktik) | US Army / AF doctrine | Commander's Intent model for batch descriptions, situational awareness passing | Assumed persistence between units (sub-agents don't persist) |
| OPORD/WARNORD/FRAGORD | Military operational planning | Progressive order types mapped to plan/briefing/update | FRAGORD's delta model (sub-agents need full briefing, not deltas) |
| Backbrief | Military pre-execution | Verification step after batch execution | Pre-execution backbrief (harness verifies after, not before) |

### Adaptation Process

The user's consistent guidance was: "refer back to specific frameworks"
(L752), "what do the frameworks say?" and "remember the limitations and
capabilities of our harness and the need to adapt/adopt these frameworks
to those constraints" (L1236).

The agent's approach evolved across the session. Early responses (L703)
were gut-based. After the user's pushback at L752, the agent began
explicitly grounding every recommendation in a named framework and citing
the specific principle. The user rewarded this with "thats beautiful"
(L1194) when the delegation duty was framed this way.

The harness constraint adaptation (L1238) was the maturation point:
the agent explicitly listed five constraints that limit how military
doctrine applies (no persistence, no inherited rules, no mid-execution
updates, no peer communication, post-execution verification only). This
prevented the military metaphors from becoming cargo cult labels.

---

## 5. Plan Evolution (Revision by Revision)

### Revision 1 (L1033, 21:31) -- Initial Draft
Written by a Plan subagent after three parallel pre-investigations.
8 batches, two major efforts (incidents rename + tool-ops framework).
**Problem**: Framing implied CC is the harness platform.

### Revision 2 (L1048-1062, 21:32-21:33) -- Framing Fix
Single edit: corrected the framing to "aitools = harness, CC = first
tool with ops entry." Verified no other instances of the conflation.

### Revision 3 (L1090, 21:41) -- Governed Term Audit
Full rewrite from scratch. Six ambiguities fixed: "Trigger" became
"Discovery context", `deployMode` became `governanceModes`, "absorbed"
became "merged in, source deleted", `docAccessPattern`/`testingPattern`
became `docAccess`/`verificationMethod`, "trigger directive" replaced with
"cross-reference to governing rule." Every governed term usage verified.

### Revision 4 (L1203, 22:24) -- Execution Protocol Added
Full rewrite. New section: "Execution Protocol" with 5 instructions for
all sub-agents. Added "delegation context" sections to every batch.
Known states documented (phantom tool-registry.json, maintenanceFile
pointing to file being deleted, unfiled findings from this session).
Multiple user interventions during drafting:
- "wtf is bootstrap?" (L1115) -- agent did 4 passes to remove ambiguity
- "it should look at the skill itself but not invoke it" (L1122)
- "note the bad state of tool-registry.md" (L1129)
- "audit for similar annotations to the known state" (L1135)
- "include delegation duty instructions" (L1187)

### Revision 5 (L1238, 22:33) -- Military Adaptation
Full rewrite. Execution protocol step 6 (delegation duty) now documents
5 harness constraints limiting military mission command application.
Each batch gained "Situational awareness for briefing" sections.
Risk assessment gained item 7 (sub-agent context gap as a risk).
Grounding section added mission command with adaptation note.

### Revision 6 (L1260, 22:40) -- Generalized Delegation
Full rewrite. All "main agent" references replaced with "delegating
agent" / "delegated agent." Step 6 made universal and recursive: "Any
agent that delegates work to another agent must follow this duty. This
applies recursively." Batch briefing sections renamed from "Situational
awareness for sub-agent briefing" to "Situational awareness for briefing."

### Revision 7 (L1273, 22:50) -- Identity and Plan Inclusion
Full rewrite. Two new bullets in step 6: "Include the plan" (the
delegated agent cannot follow deviations from a plan it was never given --
a FRAGORD without the base OPORD) and "Establish identity" (role
description, batch ownership, how work fits the larger effort). Each
batch gained an "Identity for delegated agent" section.

### Final Edits (L1294-1303, 22:56-22:57)
Three targeted edits: opening addressee ("You are the executing agent
reading this plan"), protocol opening ("you, the executing agent"),
batch plan intro ("You delegate... You are the only element that
persists").

---

## 6. Military Doctrine Parallels

### How They Emerged

The military doctrine connection was **agent-initiated** (L1224, 22:26)
after the user asked to "do one more pass" (L1229). The agent researched
via WebSearch (L1211-1219) and identified three frameworks. The user then
drove the adaptation phase, ensuring the doctrine was not adopted
wholesale but mapped to harness constraints.

### Mission Command (Auftragstaktik)

**Doctrine**: "Commanders direct what and why; subordinate commanders
devise how." Four requirements: authority, communication, situational
awareness, situational understanding.

**How it maps**: The plan's execution protocol is an OPORD; each batch's
delegation context is a WARNORD; the delegation duty (step 6) is the
Mission Command principle itself. Sub-agents have authority (tools),
communication (prompt), situational awareness (what came before), and
situational understanding (how their batch fits the larger effort).

**Where it breaks**: Military units persist, communicate laterally, and
receive mid-mission updates. Sub-agents start fresh, cannot communicate
with peers, and receive no updates during execution. The agent explicitly
documented these five constraints at L1238.

### OPORD / WARNORD / FRAGORD

**Doctrine**: Progressive order types. OPORD is the full operational
order (5 paragraphs: Situation, Mission, Execution, Sustainment,
Command & Control). WARNORD is advance notice. FRAGORD is a delta
update to a base order.

**How it maps**:

| Military | Harness Equivalent |
|----------|-------------------|
| OPORD | The plan file |
| WARNORD | "What the sub-agent needs to know" in each batch |
| FRAGORD | Delegation duty: "check for deviations, update the prompt" |

**Critical adaptation** (L1268): The agent caught that the original
briefing format was a FRAGORD without a base OPORD -- telling sub-agents
about deviations from a plan they were never given. The fix: include the
relevant plan sections in every briefing.

### Backbrief

**Doctrine**: "Conduct a backbrief at the end of the OPORD to ensure
personnel understand the order."

**How it maps**: The verification step after each batch is the backbrief.

**Where it breaks**: Military backbriefs happen before execution (to
confirm understanding). In the harness, verification happens after
execution (sub-agents can't backbrief because they're created, work,
and end). The delegating agent verifies after, not before.

### AAR (After Action Review)

The session itself is an instance of the AAR doctrine. Not explicitly
discussed in the transcript, but the user's request for this document
is the fourth element of the cycle: plan, execute, verify, review.

---

## 7. What Went Right

### 1. The investigation skill pattern worked beautifully
The user's escalation from "fix it" to "use your investigate skill"
(L51) changed the trajectory of the session. The structured RCA format
produced not just a fix but the insights that motivated the entire
framework.

### 2. Chrome-devtools for official docs
Reading the CC hooks/permissions/sub-agents docs via chrome-devtools
(L103-170) provided the exact schema details needed. The agent noted:
"WebFetch would have summarized and we'd have missed critical lines like
'SubagentStart hooks cannot block subagent creation.'" This validated a
principle that became part of tool-ops.

### 3. User interrupts prevented wasted work
The user interrupted 14 times during the session (L523, 537, 555, 767,
791, 845, 848, 1109, 1113, 1234, 1269, 1281, 1319 plus implicit ones
where the text shows "[Request interrupted]"). Each interrupt redirected
before the agent went too far down a wrong path. The most impactful:
L1109 interrupted a rewrite to add the execution protocol concept, and
L1115 caught "bootstrap" as an undefined term.

### 4. Subagent investigations in parallel
Three investigations ran in parallel at L866-892 (framework adoption
pattern, incidents rename blast radius, cascade manifest connection).
Three more earlier at L716-719 (glossary hook, MANIFEST search) plus
one at L558 (registry bypass). Each produced findings that shaped the
design. The registry bypass investigation (L558) revealed the phantom
file defect. The glossary hook investigation revealed that "prevention
working means detection stays dormant" -- a critical insight for
tool-ops hook design.

### 5. The user's "ground it in frameworks" push
At L752, the user demanded framework-grounded recommendations. This
elevated the entire design process. Instead of "I think audit-first is
right," the agent produced: "SRE operational readiness reviews (Ch. 32)
say checklists before automation. Hook-rollout says observe-then-enforce.
Managed-file-deployment says discover-validate-deploy." The user rewarded
this consistently ("thats beautiful", "love it").

### 6. Multi-pass ambiguity removal
The agent's 4-pass ambiguity removal at L1117 (identify terms, rewrite
in plain language, check remaining ambiguity, check for gaps) was
effective and became a repeatable pattern. The user validated it and the
process was applied to subsequent rewrites.

### 7. The governed term audit
The agent proactively audited the plan for governed term misuse
(L1066-1094) before the user asked. Finding that "Trigger" had been
used loosely -- conflating with the DTCC trigger definition -- prevented
a governance ambiguity in the plan itself. "Ambiguity is a defect" was
applied to the plan, not just the codebase.

### 8. Live testing of the hook
Deploying the hook mid-session and testing it live (L375-379) provided
immediate feedback. The hook picked up via ConfigChange event --
something the agent wasn't sure would work. This empirical verification
built confidence in the approach.

---

## 8. What Could Improve

### 1. Session length and scope creep
A 2h49m session covering incident investigation, implementation,
framework design, schema design, plan writing, and seven plan rewrites.
The agent suggested stopping at L695 ("Want me to commit what we have so
far and then plan tool-ops as a separate session? This one's getting
long.") The user overrode: "nah lets keep going." The session stayed
productive but at 185k tokens (19% of 1M context) was starting to push
boundaries.

**Lesson**: When the user wants to keep going, the scope management
burden shifts to ensuring each phase's outputs are captured (the plan
file serves this purpose). The agent adapted by writing scratch files
for each investigation, which is the right pattern.

### 2. Seven plan rewrites are too many
Each rewrite was individually justified, but the cumulative effect was
~1 hour of rewriting. The root causes:
- **Missing requirements surfaced incrementally**: delegation duty (R4),
  identity briefings (R7), and harness constraints (R5) were discovered
  during writing, not during design. These should have been identified
  during the Phase 4 design conversation.
- **Governed term audit happened post-write**: Revision 3 was entirely
  about fixing governed term misuse. A pre-write term audit would have
  avoided this full rewrite.

**Lesson**: Before entering plan mode, explicitly verify: (1) all
requirements are enumerated, (2) all governed terms in the draft are
used correctly, (3) the execution model is defined (who executes, how
they delegate, what context they carry). The user's L857 question
"do we have enough to remove all ambiguity?" should trigger a checklist,
not just an affirmative.

### 3. The "bootstrap" term should not have appeared
At L1112, the agent used "bootstrap" in the execution protocol --
a term not defined in the governed vocabulary. The user caught it
immediately (L1115). The agent should have applied the governed term
discipline to its own protocol drafts, not just to the plan prose.

### 4. The hook-can't-use-skills realization came late
At L779, the user realized: "oh fuck because its a hook it cant use
a skill right?" This fundamental constraint should have been surfaced
when hook-based enforcement was first proposed (L766), not after. The
agent should proactively flag harness constraints when proposing
patterns that might violate them.

### 5. No commit was made during the session
The agent offered to commit at L227 and L517. The user chose to keep
going. The working code (deny fix, hook, test suite) remained
uncommitted for the entire session. If the session had crashed, all
implementation work would have been lost (the .scratch files would
survive but the setup script edits would not).

**Lesson**: For sessions that produce working code AND then shift to
planning, push for a mid-session checkpoint commit. The two phases
(implementation and planning) are independently valuable.

### 6. The per-capability switch count grew without constraint
The governance modes grew from 1 switch (deployMode: audit/active) to
6 switches (denyRules, hooks, contextInjection, kpis, versionDeps,
verifications) across a 20-minute conversation. Each addition was
individually reasonable but the cumulative complexity was never assessed.
Six binary switches per tool is 64 possible states -- is that testable?

**Lesson**: When a design dimension grows, periodically ask: "is this
the simplest thing that solves the problem, or are we over-engineering?"
The user's original instinct was "one switch" (L759). The per-capability
model is probably correct but should have been tested against a
simplicity check.

### 7. Some framework citations were from memory, not verification
The agent cited "Google SRE Book, Chapter 32" and "Ohno, Toyota
Production System" and "Argyris' double-loop learning" without
actually reading those sources during the session. Chrome-devtools
was used for CC docs but not for validating framework citations.
These may be accurate but they're unverified.

---

## 9. Lessons for Future Plans

### For the planning process

1. **Enumerate requirements before writing.** The delegation duty,
   identity briefings, and harness constraint documentation were all
   discovered during or after writing. A "requirements enumeration"
   step between design and plan-writing would reduce rewrites.

2. **Pre-write governed term audit.** Before writing any plan that
   will be executed by sub-agents, scan the draft for governed terms
   and verify correct usage. The post-write audit at Revision 3 cost
   a full rewrite.

3. **Checkpoint commits at phase boundaries.** When a session shifts
   from implementation to planning, commit the implementation. The two
   deliverables have independent value and independent risk.

4. **Complexity checks during design.** When a dimension grows (one
   switch becomes six), pause to assess whether the complexity is
   justified by the use case. "Is there a simpler design that covers
   80% of the value?" is always worth asking.

### For the delegation model

5. **The delegation duty is a framework-level concept.** What emerged
   in this session -- execution protocol, delegation duty, identity
   briefings, carry-awareness -- transcends this plan. These concepts
   should be formalized in the harness so all future plans benefit.
   The user recognized this implicitly by demanding the protocol be
   written in generalizable language.

6. **Adapt, don't adopt.** Military doctrine validated the intuitions
   but required explicit adaptation. The five harness constraints
   documented at L1238 (no persistence, no inherited rules, no
   mid-execution updates, no peer communication, post-execution
   verification) are durable reference material for any framework
   adoption that involves multi-agent coordination.

7. **Identity matters.** The user's insight that sub-agents need to
   know "who they are, what role they play, how their work fits the
   larger effort" (L1271) addresses a failure mode that information
   alone doesn't solve. A sub-agent that knows it's "the schema
   migration agent" makes different (better) decisions than one that
   just receives a task list.

### For the user-agent relationship

8. **User interrupts are a feature.** Fourteen interrupts in this
   session, each productive. The user's ability to redirect before
   the agent goes too far is a critical quality control mechanism.
   The agent should treat interrupts as signal, not friction.

9. **"Ground it in frameworks" is a forcing function.** The quality
   of the agent's output measurably improved after L752 when the user
   demanded framework-grounded recommendations. This is a repeatable
   technique: when an agent is making gut calls, ask "what do the
   frameworks say?"

10. **The user drives architecture; the agent drives implementation.**
    Every architectural decision in this session (framework, not ad hoc;
    merge gaps and incidents; per-tool per-capability; delegation duty;
    identity briefings) was user-initiated. Every implementation detail
    (mock-JSON-pipe testing, JSON schema design, verification spec
    format, hook script structure) was agent-initiated. This division
    of labor worked.
