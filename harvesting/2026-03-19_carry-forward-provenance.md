# Carry-Forward Concept: Provenance and Evolution

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-18
**Sources audited**: planning-brief.json (49K tokens), 3 session transcripts,
delegation-evolution.md, carry-forward-design.md (813 lines),
framework-adoption.md, aitools-workspace.md, harness.md, git history (5 key commits),
research-synthesis.md

---

## 1. Timeline

### Phase 1: The Seed — "carry awareness" (2026-03-15, session 84280c8b)

The concept first appears at line L1187 of the tool-ops planning session
when the user articulates what becomes "delegation duty":

> "also, include instructions for the executing agents that, before they
> delegate work to a subagents, they need to review and update the
> instructions passed on what has been accomplished thus far, and if we
> have deviated from the plan, and if other things have surfaced.
> basically, all executing agents have a duty to improve and refine the
> prompt they are delegating to the delagating agent. the executing
> agent should know, as much as they can, they are one piece of a
> larger puzzle."
>
> — User, session 84280c8b, L1187, 2026-03-15

The user's reaction to the agent's formalization: **"thats beautiful"** (L1194).

At L1224, the agent independently connected this to **Mission Command
(Auftragstaktik)** and the **OPORD/WARNORD/FRAGORD** framework. The
delegation duty became a FRAGORD: the delta update that each delegating
agent must produce.

At L1283, the user explicitly names the concept:

> "to answer your last question, yeah i think the answer is yes.
> re-write the plan one more time from scratch to implement that
> **'carry awareness'** in the opening of the plan itself and audit for
> other places"
>
> — User, session 84280c8b, L1283, 2026-03-15

The agent implemented "carry awareness" as three reinforcement points:
the opening addressee, the protocol opening ("you, the executing agent
reading this plan"), and the batch plan intro ("You delegate... You are
the only element that persists").

At this stage, "carry awareness" meant: **the delegating agent's duty to
pass accumulated context to each delegated agent**. It was intra-session,
intra-plan, about delegation — not about cross-machine state.

### Phase 2: Cross-Machine Discovery (2026-03-16, session b8a9ed4e)

During the 6-hour mission analysis session, the concept expanded in two
directions:

**Direction A: Session lifecycle and cross-machine visibility**

Decision #1 (session archive auto-commit/push) was triggered by the user
discovering that switching from macOS to Windows made 3 sessions invisible.
The rationale:

> "3 sessions invisible cross-machine because archive hook copies
> transcripts but does no git ops. 'User commits on their own schedule'
> creates predictable cross-machine gap."
>
> — Planning brief, decision #1

This is the first time "carry-forward" was applied to **cross-machine state**
rather than intra-session delegation context.

**Direction B: Workspace namespace consolidation**

Decision #34 came from the user realizing that Mission Command, Mission
Analysis, scratch, channel, and harvesting are all harness capabilities
that should be given to users across projects:

> "Mission Command and Mission Analysis: this is stuff we want to give
> to our users. .channel should instead be .aitools/channels or
> something like that. also scratch is something and harvesting is
> something we want to give to our users"
>
> — User, session b8a9ed4e, ~L2600, 2026-03-16 (from session audit)

### Phase 3: Running Estimate — Military Doctrine Formalization (2026-03-16, session 79b05dd0/37ab88e4)

An S2 subagent (session uyZ7TELqpP) produced the 813-line
`carry-forward-design.md`, which traced the concept to its doctrinal
source:

> **ADP 5-0 (The Operations Process, July 2019)** defines a running
> estimate as "the continuous assessment of the current situation used
> to determine if the current operation is proceeding according to the
> commander's intent and if planned future operations are supportable."

Key doctrinal property identified:

> "At handoff, the running estimate IS the carry-forward. During relief
> in place or battle handover, the outgoing staff passes running
> estimates to the incoming staff. The estimate contains everything the
> incoming officer needs to continue operations without re-deriving the
> situation."
>
> — carry-forward-design.md, Section 1, property 4

The design document explicitly resolved the naming:

> "'Carry-forward' describes the action (carrying information forward)
> but not the artifact. 'Handoff brief' implies a one-time event.
> 'SITREP' is a message type we already have in the channel. The
> running estimate is the continuously maintained state document that
> SITREPs update."
>
> — carry-forward-design.md, Section 2

And acknowledged the evolution:

> "'Carry-forward' was the working label before we identified the
> doctrinal source."
>
> — carry-forward-design.md, Section 8, Q/A

### Phase 4: Codification in Rules (2026-03-16, commits 69cfd78 and 77ffd07)

**Commit 69cfd78** (2026-03-16 19:17:04) created
`.claude/rules/aitools-workspace.md` with the cross-machine carry-forward
principle and simultaneously updated the user's CLAUDE.md template
(dotprofile commit 1e53bcf):

> "Project working state (running estimates, consolidated findings,
> harvested artifacts) must carry forward across machines — if I switch
> from Mac to Windows on the same project, I pick up where I left off.
> Track carry-forward state in git; gitignore session-ephemeral data"
>
> — User CLAUDE.md, Cross-Platform Awareness section (added 2026-03-16)

**Commit 77ffd07** (2026-03-16 19:57:36) amended 5 planning brief decisions
(#3, #22, #26, #34, #50) to align with the workspace rule's carry-forward
principle.

### Phase 5: Mission Statement Elevation (2026-03-17, commit d534f3c)

The most recent commit elevated "carry-forward" into the project's mission
statement in CLAUDE.md:

> "The harness — aitools and the tools, context, state, artifacts,
> frameworks, and provenance it manages — gives every project it
> touches governance frameworks, artifact harvesting, session state
> **carry-forward**, and provenance tracking."
>
> — CLAUDE.md mission paragraph (added 2026-03-17)

---

## 2. User Quotes (weighted by recency)

### Highest weight (2026-03-16, current standards)

**The carry-forward principle** (user CLAUDE.md, commit 1e53bcf):
> "if I switch from Mac to Windows on the same project, I pick up where
> I left off"

**The workspace namespace** (session b8a9ed4e audit, ~L2600):
> "this is stuff we want to give to our users"

### High weight (2026-03-15, framework adoption)

**The delegation duty origin** (session 84280c8b, L1187):
> "all executing agents have a duty to improve and refine the prompt...
> the executing agent should know, as much as they can, they are one
> piece of a larger puzzle"

**The "carry awareness" naming** (session 84280c8b, L1283):
> "re-write the plan one more time from scratch to implement that
> 'carry awareness' in the opening of the plan itself"

**The "beautiful" moment** (session 84280c8b, L1194):
> "thats beautiful"
(in response to the delegation duty formalization)

---

## 3. Framework Provenance Connections

| Discipline | Source | What it contributed |
|------------|--------|-------------------|
| **Military operations** | ADP 5-0 The Operations Process (July 2019) | Running estimate concept, "continuous assessment," handoff = pass the estimate |
| **Military operations** | Mission Command (Auftragstaktik) | "Carry awareness" — the delegating agent carries context that subordinates don't have |
| **Military operations** | OPORD/WARNORD/FRAGORD (FM 101-5-2) | Delegation duty as FRAGORD: delta updates from accumulated state |
| **Military operations** | ATTP 5-0.1, FM 6-0 | Running estimate standard format (situation, mission, analysis, comparison, conclusions) |
| **Military operations** | Staff Processes in LSCO (2024) | "Conclusions first" principle — lead with assessment, not facts |
| **SRE** | Operational handoff | Decision #1 rationale: "state must be visible to the next operator" |
| **Quality management** | PDCA (Plan-Do-Check-Act) | The discovery-to-continuation cycle (DTCC) step 9 — "continuation" IS carry-forward of the interrupted work |

### The DTCC Connection

The Discovery-to-Continuation Cycle (framework-adoption.md) has
"continuation" as its 9th and final step. This is carry-forward applied
to the harness evolution process itself:

> "Resume the work that was interrupted by the discovery. Before
> continuing, assess whether the discovery changed the plan."

The word "continuation" in DTCC was not named as carry-forward, but it
IS carry-forward: the harness state changed, now carry that forward into
the remaining work. This is **double-loop learning** (Argyris) — not
just fixing the problem, but recognizing the framework evolved.

---

## 4. The Most Evolved Version

The most evolved version of the carry-forward concept is **Decision #50
in the planning brief** combined with the **carry-forward-design.md**
(813-line harvested artifact). Together they provide:

1. **Formal name**: "running estimate" (governed term, replaces
   "carry-forward" as the artifact name)
2. **Doctrinal source**: ADP 5-0, The Operations Process
3. **Schema**: Full JSON schema with meta, situation, findings,
   conclusions, delegationLog
4. **Lifecycle**: Created by S2 at plan start, maintained by S3 during
   execution, consolidated by S2 at plan end, archived at session end
5. **Cross-session mechanism**: Archived to `.aitools/harvesting/`,
   next session's S2 reads it
6. **Cross-machine mechanism**: Lives at
   `.aitools/channel/running-estimate.json` (tracked in git, fixed path)
7. **Relationship to other artifacts**: SITREPs and FINDINGs are inputs;
   running estimate integrates them; AAR is produced from it
8. **KPIs**: estimateMaintenanceRate (100%), estimateVersionsPerPlan
   (>= batches + 2), carryForwardSuccessRate (>= 90%)

The design explicitly acknowledges the evolution:

> "The JSON in the S3 delegation prompt that started this session IS a
> running estimate, just without the name or schema... This validates
> the design: the ad-hoc carry-forward naturally converges on the
> running estimate structure."
>
> — carry-forward-design.md, Section 6

---

## 5. Current Workspace Rule vs. Most Refined Version

### What the workspace rule says now

```
### Cross-machine carry-forward principle

A user working on the same project across multiple machines (macOS,
Windows) must be able to pick up where they left off. Project state
that carries forward between sessions — running estimates, consolidated
findings, harvested artifacts — MUST be tracked in git so it survives
machine switches via pull.

Session-ephemeral data (scratch files, in-flight channel messages)
is gitignored — it belongs to one session on one machine.

This principle governs every workspace design decision: if data
needs to survive a machine switch, it must be tracked.
```

### What the evidence supports but the rule does not capture

1. **Three scopes of carry-forward, not one**: The concept evolved
   through three scopes, but the rule only addresses scope 3:
   - **Intra-session carry-forward** (delegation duty, L1187): Each
     delegating agent carries accumulated context to its delegated
     agents. Governed by delegation duty component 3 in decision #4.
   - **Cross-session carry-forward** (running estimate, decision #50):
     The running estimate is archived and read by the next session's S2.
     Mechanism: `.aitools/harvesting/` archive + S2 intelligence prep.
   - **Cross-machine carry-forward** (workspace principle): Git-tracked
     state survives machine switches. Mechanism: git commit + pull.

   The workspace rule addresses only scope 3. Scopes 1 and 2 are
   addressed by decision #4 and decision #50, but no rule ties them
   together as the "carry-forward principle."

2. **The running estimate IS the carry-forward artifact**: Decision #50
   component (1) explicitly states: "Governed term: 'running estimate'
   (not carry-forward)." Yet the workspace rule uses "carry-forward" as
   the principle name and mentions "running estimates" as just one
   example. The running estimate is THE primary carry-forward mechanism,
   not merely an example.

3. **The "conclusions first" doctrine**: The carry-forward design cites
   recent Army doctrine criticizing estimates that bury conclusions at
   the end. The workspace rule does not mention that carry-forward state
   should lead with assessment/conclusions.

4. **The DTCC continuation connection**: Step 9 of the DTCC (Continue)
   is carry-forward applied to harness evolution. The workspace rule
   does not connect to the DTCC.

5. **"The only element that persists"**: The plan's opening uses this
   phrase for the executing agent. It is the deepest articulation of
   carry-forward: in a system where agents don't persist, the state
   document IS the persistence mechanism. The workspace rule uses the
   gentler "pick up where they left off."

---

## 6. Recommendation

The carry-forward principle was improved upon when Session 84280c8b's
"carry awareness" (a delegation duty for intra-session context passing)
was connected to ADP 5-0's running estimate doctrine by the S2
investigation in session uyZ7TELqpP. The improvement was:

- **Before**: "Carry awareness" — an informal obligation on delegating
  agents to update their delegation briefings with accumulated state.
  No formal artifact. No schema. No lifecycle.

- **After**: "Running estimate" — a continuously maintained JSON state
  document with doctrinal provenance (ADP 5-0), formal schema, defined
  lifecycle (created/maintained/consolidated/archived), cross-session
  mechanism (archive + S2 intelligence prep), and cross-machine
  mechanism (git-tracked fixed path). The ad-hoc carry-forward was
  formalized into a first-class harness artifact.

The workspace rule should be updated to reflect all three scopes and
explicitly name the running estimate as the primary carry-forward
mechanism, not just an example. The recommended text would:

1. Name the three scopes (intra-session, cross-session, cross-machine)
2. Connect "carry-forward" to its doctrinal source (ADP 5-0 running
   estimate)
3. Reference the delegation duty (decision #4) for intra-session scope
4. Reference the DTCC step 9 (continuation) for harness evolution scope
5. Retain the "pick up where I left off" language — it is the user's
   own articulation of the principle

However, this update depends on the Mission Command framework being
implemented (the running estimate schema and lifecycle from decision #50
are still "proposed" status). Until then, the current rule correctly
governs the cross-machine scope and mentions running estimates as a
forward-looking example of carry-forward state.
