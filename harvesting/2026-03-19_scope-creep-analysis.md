# Scope-Creep Analysis and Governance Framework

**Analyst**: S2 (Intelligence)
**Date**: 2026-03-18
**Scope**: Part 1: immediate action options for current session. Part 2: scope-creep governance framework design (three-layer). Part 3: briefing decomposition into self-contained sub-briefings. NOT implementation. NOT plan writing.

---

## Part 1: Immediate Action -- What Should the User Do Next?

### Current Session State

**Completed (verified)**:
- R7: 28 governed JSON paths removed from 10 files
- R8: Step 16 reclassified, now passes
- R10: Harness definition updated across CLAUDE.md, harness.md, glossary.json
- Incident #50 filed (sources-of-truth bypass vectors)
- v0.62.2 shipped (governed-data bypass fixes + harness definition)
- Post-push bug briefing complete (D1-D4 fully specified)
- Briefings location decided (.aitools/briefings/)
- Q4 lifecycle investigation complete
- Q10 artifact-roles investigation complete
- Q4-Q10 ambiguity audit complete (3 blockers, 15 should-resolve, 15 informational)

**Started, draft ready, NOT committed**:
- R1-R3: Intent skill heuristic updates -- drafts exist, not written to skills
- Repo/project terminology definitions -- proposed, not filed via /glossary
- Promotion definition -- identified as blocker in Q4-Q10 audit, not filed
- Carry-forward principle rewording -- researched, not drafted into workspace rule

**Started, investigated, NOT decided**:
- Artifact-roles framework -- 3 options analyzed, Option C+A recommended, user has not approved
- R13: incident-governance.md 3 remaining JSON refs -- user had approach, not executed

**Not started (open recommendations)**:
- R4: Intent statements for 14 rules + 6 skills
- R5: Extend governed-data hook to all registries
- R6: Review observe-mode log data
- R9: New rules-json-guard hook
- R11: Artifact-roles rule + skill creation
- R12: Registries directory move (59 files, deferred)

### Dependency Graph

```
Briefings location decision
    |
    +---> .gitignore restructuring (BLOCKS namespace consolidation)
    +---> Workspace rule amendment (briefings row + carry-forward rewording)
    +---> /glossary: "repo", "project", "briefing", "promotion" terms
    |
Post-push bug briefing
    |
    +---> D2 fix (bash 3.2 process-substitution) -- self-contained
    +---> D3 fix (BSD paste) -- self-contained, parallel with D2
    +---> D4 detection (paste compliance check) -- after D3
    |
Intent skill drafts (R1-R3)
    +---> Write to skill files (approval needed)
    |
Artifact-roles framework
    +---> User decision on Option C+A
    +---> harness.md /artifact-roles reference resolution
    |
incident-governance.md (R13)
    +---> User approach -- 3 refs to address
```

### What Has Highest Leverage

The session has produced extensive analysis but low commit-to-investigation ratio. 7 of 13 recommendations are complete, but the remaining 6 are all medium-to-high effort. The biggest constraint is that multiple threads are open and none is close enough to the finish line to ship with a quick push -- each needs a new decision or approval step.

The post-push bug briefing is the exception: it is fully specified, self-contained, and blocks nothing except the reliability of the check script. However, it is an S3 task (execution), not intelligence work.

---

### Option A: Ship the Post-Push Bug Fixes (Most Impactful Single Action)

**Instruction to agent**: "Execute the post-push bug briefing. Fix D2 (bash 3.2 heredoc) and D3 (BSD paste) in parallel using sub-agents, then D4 (compliance check). The briefing is at `.scratch/session-Z1IhGrcgGO/post-push-fix-briefing.md`. Verify all acceptance criteria."

**What this unblocks**:
- check-post-push.sh becomes reliable on macOS (currently broken since its introduction)
- Step 21 (tool version freshness) starts producing real data for the first time
- Exit code becomes trustworthy (currently exits 1 even with 0 failures)
- Future sessions can use check-post-push.sh as intended

**What remains stuck**:
- All governance threads (briefings location, artifact-roles, glossary terms, intent skills)
- Incident #50 resolution (sources-of-truth overhaul)
- Namespace consolidation (.gitignore blocker)

**Barrier analysis**: This is the only thread with a fully specified, verified briefing ready for delegation. It produces a tangible, testable improvement. The risk is that it is an operational fix, not a strategic advance -- the governance work remains untouched.

---

### Option B: Close the Glossary Gap (Safest -- Close Open Threads)

**Instruction to agent**: "File via /glossary: 'briefing', 'promotion', 'repo', 'project'. These are blockers and should-resolves from the Q4-Q10 ambiguity audit. Definitions are drafted in `.scratch/session-Z1IhGrcgGO/briefings-location-decision.md` section 2 and `.scratch/session-Z1IhGrcgGO/q4-q10-ambiguity-audit.md` Pass 1. Then write the intent skill updates (R1-R3) -- drafts are ready. Present all changes as a batch for approval."

**What this unblocks**:
- Removes 1 blocker ("promotion" undefined) from Q4-Q10 audit
- Resolves 2 should-resolves ("briefing", "repo"/"project" terminology)
- Commits R1-R3 intent skill heuristics that are already drafted
- Reduces open threads from 6 to 2-3

**What remains stuck**:
- Post-push bugs (not addressed)
- Artifact-roles decision (still needs user approval)
- Namespace consolidation (.gitignore blocker)
- Incident #50 (sources-of-truth overhaul)

**Barrier analysis**: This is the lowest-risk option. All content is already drafted and just needs filing through the governed process. The definitions have been discussed and the user has stated preferences. The intent skill drafts (R1-R3) are ready to write. This closes threads without opening new ones. The risk is that it is housekeeping -- valuable for future sessions but produces no visible feature improvement.

---

### Option C: Commit the Briefings Location Decision + .gitignore Fix (Most Strategic)

**Instruction to agent**: "Implement the briefings location decision from `.scratch/session-Z1IhGrcgGO/briefings-location-decision.md`. Three changes: (1) Restructure `.gitignore` from blanket `.aitools/` to selective patterns per section 3. (2) Amend workspace rule: add `briefings/` row, update governing principle text, reword carry-forward principle. (3) Amend decision #34 via /brief: add component (14) for briefings. Present all changes as a batch."

**What this unblocks**:
- .gitignore restructuring unblocks the ENTIRE namespace consolidation (decision #34)
- harvesting/ migration to .aitools/harvesting/ becomes possible
- Running estimate tracking (.aitools/channel/running-estimate.json) becomes possible
- Briefings can be placed at .aitools/briefings/ and tracked in git
- Every future session that touches workspace structure benefits

**What remains stuck**:
- Post-push bugs
- Glossary terms
- Intent skills
- Artifact-roles framework

**Barrier analysis**: This is the highest long-term leverage. The .gitignore blocker is identified in the briefings-location analysis as blocking the entire namespace consolidation -- not just briefings. Every workspace feature (harvesting, running estimate, briefings) that needs git tracking is blocked by the blanket `.aitools/` pattern. Fixing it is a prerequisite for multiple planning brief decisions (#34, #22, #50). The risk is scope: the carry-forward principle rewording touches the workspace rule's governing principle (a protected file), and the decision #34 amendment requires /brief skill interaction. This could expand into another investigation thread if complications arise.

---

### Recommendation

**Option A (post-push bugs) is the recommendation for RIGHT NOW**, for three reasons:

1. **It is the only thread with a complete, verified briefing ready for immediate S3 delegation.** Every other option requires additional decisions, approvals, or protected-file review gates.

2. **It addresses a real operational failure.** check-post-push.sh has never worked correctly on macOS. The exit code issue means every post-push verification has been unreliable.

3. **It can be completed in a single delegation.** The briefing specifies parallel sub-agents for D2 and D3, with verification criteria. Estimated: 30-45 minutes.

After A completes, do B (glossary + intent skills), then C (.gitignore + workspace rule). This sequence closes the most threads per unit of effort.

---

## Part 2: Scope-Creep Governance Framework

### Provenance

Scope-creep governance draws from several established disciplines:

| Discipline | Key concept | How it applies |
|-----------|------------|----------------|
| **Project management (PMI/PMBOK)** | Scope baseline + change control | Every session, briefing, and plan has a declared scope. Changes to scope require explicit approval (FRAGORD pattern). |
| **Military mission analysis (MDMP)** | Commander's intent constrains scope | The intent statement IS scope governance at the file level. "Purpose, scope, audience" directly answers "what belongs here and what does not." |
| **Military operations (OPORD/FRAGORD)** | Scope changes are explicit amendments | No silent scope expansion. Changes to session scope are FRAGORDs -- acknowledged, documented, traceable. |
| **Software engineering** | Single responsibility principle (SRP) | Each file, skill, rule, session has ONE job. Scope creep is the SRP violation at the process level. |
| **Lean / Toyota Production System** | Limiting work-in-progress (WIP) | The failure mode in this session was unbounded WIP. Every new topic was legitimate but accumulated without closure. WIP limits prevent this. |
| **The harness's own intent framework** | Intent IS scope | Purpose/scope/audience already governs files. Extending it to sessions, briefings, and plans is the natural generalization. |

### The Core Insight

Scope creep in this harness is not about bad ideas -- every topic explored in the current session was legitimate and valuable. The failure mode is:

**Opening rate exceeds closing rate.**

The session started 12+ threads. It completed 7. The remaining 5 each spawned sub-threads (Q4 lifecycle, Q10 artifact-roles, ambiguity audit, briefings location, repo/project terminology). Each sub-thread was a legitimate discovery. But the session never returned to close earlier threads because each discovery was more interesting than the closure task.

This is the WIP problem: every open thread consumes context, creates dependencies, and competes for attention. The solution is not to prevent discoveries (that would break the surfacing duty) but to govern the transition from discovery to execution.

### Framework Design: Three Layers

#### PREVENTION Layer

**P1: Session scope declaration (new)**

Every session that will do work (not just research) declares its scope at the start. Format matches the harness intent pattern:

```
Session scope:
- Purpose: [what this session will deliver]
- Scope: [what is in, what is explicitly out]
- WIP limit: [maximum concurrent open threads, default 3]
```

The scope declaration is NOT a plan -- it is a constraint. It says what the session will NOT do, not what it will do. The agent proposes; the user approves.

**Where it lives**: Rule (`.claude/rules/session-scope.md` or integrated into an existing rule). Trigger: SessionStart hook injects the scope declaration prompt after channel/scratch init.

**P2: Briefing scope declarations (extend existing)**

Every briefing, plan, and investigation already has (or should have) an intent statement. The intent's "scope" field already declares what is NOT covered. Enforcement is the gap.

**P3: Thread ledger (new)**

The session maintains a lightweight thread ledger in the scratch directory:

```json
{
  "declared_scope": "...",
  "threads": [
    {"id": 1, "opened": "10:15", "topic": "hook testing", "status": "complete"},
    {"id": 2, "opened": "10:45", "topic": "rule effectiveness audit", "status": "open", "blocked_by": null},
    {"id": 3, "opened": "11:30", "topic": "governed-data bypass", "status": "complete"},
    {"id": 4, "opened": "12:00", "topic": "artifact-roles design", "status": "open", "blocked_by": "user decision"}
  ],
  "wip_count": 2,
  "wip_limit": 3
}
```

The agent updates the ledger when opening or closing threads. The WIP limit triggers a decision point: "Thread X would exceed the WIP limit. Close or park an existing thread first, or get user approval to exceed."

**Where it lives**: Scratch file (ephemeral). Updated by the agent. Thread ledger creation triggered by SessionStart hook. Thread open/close could be detected by a Stop hook (periodic check).

**P4: Discovery-vs-execution gate (new)**

When the agent discovers something during execution (a bypass vector, a terminology ambiguity, a missing definition), it must classify:

- **Trivial fix** (typo, missing term, one-file change): fix inline, log in thread ledger as opened-and-closed
- **Related to current scope**: fold into current thread, log as sub-task
- **New scope**: file in channel as a FINDING, do NOT open a new thread. The FINDING goes into the running estimate for the next session's S2 intelligence prep.

The critical rule: **Discoveries that are out of scope do not become threads. They become FINDINGs.** The channel infrastructure (decision #3, #22, #23) is the mechanism for parking out-of-scope discoveries without losing them.

**Where it lives**: Rule (delegation or session-scope rule). This is the highest-leverage prevention measure -- it governs the moment where scope creep happens.

#### DETECTION Layer

**D1: WIP limit enforcement (Stop hook)**

A Stop hook (fires periodically and at session end) checks the thread ledger:

- If WIP count exceeds limit: emit reminder via stderr: "WIP limit exceeded ({count}/{limit}). Close or park threads before opening new ones."
- If a thread has been open > 2 hours without a status update: emit reminder: "Thread '{topic}' has been open for {hours}. Status update or park?"
- If session scope was declared and threads exist outside that scope: flag the deviation

**D2: Scope-drift detection in briefings (extend plan-gate)**

Decision #53's plan-gate already checks for blockers. Extend it with scope-drift detection: when entering plan mode, check that the plan's scope aligns with the brief's scope. If the plan addresses decisions not in the brief, flag.

**D3: Thread closure verification (SessionEnd hook)**

At SessionEnd, the harvest hook already classifies scratch files. Extend to check the thread ledger:

- Open threads at session end are logged as FINDINGs in the channel
- Thread closure rate is a KPI (threads closed / threads opened)
- Open threads auto-populate the running estimate for the next session

#### AUDIT Layer

**A1: Session scope audit (extend /debrief)**

The AAR at session end (decision #36, /debrief skill) already produces observations, insights, and proposals. Add scope discipline as a standard AAR dimension:

- **Observation**: What was the declared scope? What threads were opened? What threads were closed?
- **Insight**: Where did scope creep happen? What trigger caused the expansion? Was the discovery-vs-execution gate followed?
- **Proposal**: Should the WIP limit change? Should the scope declaration process change? Should any open threads become roadmap items?

**A2: Briefing decomposition audit (extend /brief)**

When a brief exceeds N decisions (suggested: 15-20), the /brief skill flags it for decomposition review. The audit checks:

- Can the brief be split into self-contained sub-briefings?
- Are there decision clusters with high internal connectivity and low external connectivity?
- Can clusters be executed in parallel?

**A3: Thread-to-value tracking (future, requires telemetry)**

Once Datadog integration exists (decision #32), track:

- Thread opening rate per session
- Thread closure rate per session
- Time-to-close per thread
- Value delivered per thread (did the thread produce a commit? a decision? a filed artifact?)
- Scope-creep correlation: sessions with scope drift vs sessions with scope discipline -- which deliver more value per hour?

### Framework Artifacts (Proposed)

| Artifact | Type | Layer | Status |
|----------|------|-------|--------|
| `.claude/rules/session-scope.md` (or section in delegation rule) | Rule | Prevention | New |
| Session scope declaration in SessionStart hook | Hook extension | Prevention | New |
| Thread ledger (scratch file) | Convention | Prevention | New |
| Discovery-vs-execution gate (in delegation/session rule) | Rule | Prevention | New |
| WIP limit enforcement (Stop hook extension) | Hook extension | Detection | New |
| Thread closure verification (SessionEnd hook extension) | Hook extension | Detection | New |
| Scope discipline dimension in /debrief | Skill extension | Audit | New |
| Brief size flag in /brief | Skill extension | Audit | New |

### What This Session Would Have Looked Like with This Framework

1. **Session start**: Scope declared -- "Purpose: Test logs and verify check-post-push.sh works. Scope: Bug investigation and fix. WIP limit: 3."

2. **Hook testing**: Thread 1 opened (within scope). Completed. Thread 1 closed.

3. **Rule effectiveness audit**: Thread 2 opened. Discovery: governed-data bypass. FINDING filed in channel. Thread 2 continues with its scope (rule effectiveness), does NOT expand to governed-data remediation.

4. **Governed-data remediation**: Would NOT have become Thread 3 in this session. It would be a FINDING in the channel, picked up by the next session's S2 intelligence prep. Instead, it consumed 3+ hours and produced R7-R10.

5. **Intent audit, heuristic investigation, artifact-roles**: All would be FINDINGs, not threads. Each is a legitimate discovery that does NOT belong in a "test our logs" session.

The session would have completed in 2-3 hours instead of 8+, delivering: post-push bug fixes (the declared scope) + a set of high-quality FINDINGs for future sessions. The FINDINGs would lose no information -- they would be structured per the channel schema and available via running estimate.

### Provenance Entry (for framework-registry.json)

```json
{
  "concept": "Scope baseline and WIP limits",
  "source": {
    "discipline": "Project management + Lean manufacturing",
    "work": "PMBOK scope management (PMI), WIP limits (Toyota Production System, Kanban)",
    "key": "Scope changes require explicit change control. Work-in-progress limits prevent context switching losses."
  },
  "ownedBy": "Session scope governance (proposed)",
  "usedBy": ["Mission command", "Operational learning"],
  "adaptation": {
    "harnessMeaning": "Sessions declare scope and WIP limits. Discoveries outside scope become channel FINDINGs, not new threads. Thread ledger tracks WIP. Stop hook enforces limits. AAR audits scope discipline.",
    "implementingSkills": ["/debrief (scope dimension)", "/brief (size flag)", "/channel (FINDING destination)"]
  }
}
```

---

## Part 3: Briefing Decomposition

### Methodology

I analyzed all 54 decisions using their `related` arrays to build a connectivity graph. Decisions with high mutual connectivity (many bidirectional links) that share a framework affiliation form natural clusters. The boundary between clusters is where internal link density drops and external link density rises.

### Decision Inventory by Framework

| Framework | Decision IDs | Count |
|-----------|-------------|-------|
| Mission Command | 3, 4, 5, 6, 7, 15, 16, 17, 19, 22, 23, 24, 25, 26, 27, 28, 29, 38, 44, 46, 49, 50 | 22 |
| Operational Learning | 1, 2, 10, 11, 12, 14, 18, 30, 36, 47 | 10 |
| Mission Analysis | 13, 21, 43, 45 | 4 |
| Platform Engineering | 8, 9 | 2 |
| Intent Documentation | 39, 40, 42 | 3 |
| Infrastructure / Process | 32, 33, 34, 35, 48, 51, 52, 53, 54 | 9 |
| Merged | 31 | 1 |
| **Total** | | **51 active** |

### Connectivity Analysis

I computed the link density within and between framework groups. The `related` arrays show:

**High internal connectivity (natural clusters)**:
- Mission Command core (3, 4, 5, 6, 7, 15, 22, 23, 24, 25, 26, 27, 28): 45+ internal links
- Operational Learning core (1, 2, 10, 11, 14, 36): 18+ internal links
- Infrastructure (32, 33, 34): 4 internal links, low external

**High cross-cluster connectivity (bridge decisions)**:
- Decision #36 (Operational Learning): 17 related decisions spanning MC, ML, Infrastructure
- Decision #4 (Delegation duty): 15 related decisions spanning MC, OL, Process
- Decision #54 (Harness improvement cycle): 12 related decisions spanning all frameworks
- Decision #50 (Running estimate): 10 related decisions spanning MC, OL, MA
- Decision #51 (Plan-writing protocol): 12 related decisions spanning MC, MA, OL

**Low external connectivity (self-contained)**:
- #9 (stop hook fix): related only to #8
- #32-33 (Datadog + Auth0): related only to each other
- #17 (framework creation gate): related only to #16
- #16 (naming conventions): related only to #15, #17

### Proposed Sub-Briefings

#### Sub-Briefing 1: Foundation Infrastructure
**Decisions**: 32, 33, 34
**Intent**: Establish the technical infrastructure that all other sub-briefings depend on -- telemetry pipeline (Datadog), credential management (Auth0), and namespace consolidation (.aitools/).

**Internal connectivity**: 32<->33, 34 connects to decisions in other clusters but is infrastructural
**External dependencies**: None -- this is the base layer
**Parallel execution**: Yes, with Sub-Briefing 2

**Rationale**: These decisions have minimal cross-references to Mission Command or Operational Learning. They are infrastructure that must exist before frameworks can measure their effectiveness (KPIs depend on #32) or organize their artifacts (#34).

#### Sub-Briefing 2: Platform Engineering
**Decisions**: 8, 9
**Intent**: Fix the immediate platform bug (stop hook crash) and establish the platform engineering framework for ongoing cross-platform correctness.

**Internal connectivity**: 8<->9
**External dependencies**: None -- self-contained
**Parallel execution**: Yes, with Sub-Briefing 1

**Rationale**: Decision #9 is a concrete bug fix. Decision #8 is the framework that prevents recurrence. Both are self-contained with only one external link (#31 merged into #8).

#### Sub-Briefing 3: Intent Documentation and Enforcement
**Decisions**: 12, 39, 40, 42
**Intent**: Update the intent skills with proven heuristics (#39, #40) and build the enforcement hook (#42). Decision #12 provides the source patterns.

**Internal connectivity**: 12<->39<->40<->42 (linear chain)
**External dependencies**: #39 and #40 are marked `blocksPlanning=true` -- must complete before plan writing for the main brief
**Parallel execution**: Yes, with Sub-Briefings 1 and 2. But must complete before Sub-Briefing 6.

**Rationale**: These four decisions form a tight chain around intent quality. They are critical blockers in the planning brief and have clear verification criteria (intent approval rounds down from 3+ to 1).

#### Sub-Briefing 4: Mission Command Framework
**Decisions**: 3, 4, 5, 6, 7, 15, 16, 17, 19, 22, 23, 24, 25, 26, 27, 28, 29, 38, 44, 46, 49, 50
**Intent**: Build the complete Mission Command framework -- delegation protocol, channel infrastructure, staff functions, running estimate, agent type enforcement, FRAGORD pattern, skill naming.

**Size concern**: 22 decisions is too large for a single sub-briefing. Further decomposition:

**Sub-Briefing 4a: Channel Infrastructure** (5 decisions)
- Decisions: 22, 23, 46, 49, 50
- Intent: Build .aitools/channel/, message schemas (SITREP/FINDING), running estimate, scratch collision prevention, skill naming
- Dependencies: Sub-Briefing 1 (#34 namespace consolidation)
- Can start after: Sub-Briefing 1

**Sub-Briefing 4b: Delegation Protocol** (9 decisions)
- Decisions: 3, 4, 5, 6, 7, 15, 16, 17, 19
- Intent: Build the delegation rule, skill, and agent type enforcement. Framework naming, naming conventions, recursive delegation, session references.
- Dependencies: Sub-Briefing 4a (channel must exist for delegation to use it)
- Can start after: Sub-Briefing 4a

**Sub-Briefing 4c: Operational Coordination** (8 decisions)
- Decisions: 24, 25, 26, 27, 28, 29, 38, 44
- Intent: Staff functions (S1/S2/S3), sensors-not-filers pattern, FRAGORD, pre-draft intents, critical fact resolution, S2 AAR output format
- Dependencies: Sub-Briefing 4b (delegation protocol must exist for staff functions to use it)
- Can start after: Sub-Briefing 4b

#### Sub-Briefing 5: Operational Learning Framework
**Decisions**: 1, 2, 10, 11, 14, 18, 30, 36, 47
**Intent**: Build the Operational Learning framework -- AAR debrief, artifact harvesting, session persistence, channel archival, scratch skill guard.

**Internal connectivity**: High (36 is the hub with 17 related decisions)
**External dependencies**: Sub-Briefing 4a (channel infrastructure for archival), Sub-Briefing 1 (#34 for .aitools/ paths)
**Can start after**: Sub-Briefing 4a

**Rationale**: Decision #36 absorbs artifact harvesting and session lifecycle. It is the largest single decision (16 components) and the hub of this cluster. The cluster includes concrete fixes (#10 date mismatch, #11 manifest cleanup) and framework-level design (#36 learning loop, #1 auto-commit/push).

#### Sub-Briefing 6: Mission Analysis Framework
**Decisions**: 13, 21, 43, 45
**Intent**: Build the Mission Analysis framework -- planning brief schema, quality checklist, /brief skill, governed brief access.

**Internal connectivity**: 13<->21<->43<->45 (tight cluster)
**External dependencies**: Sub-Briefing 3 (intent skills updated before plan writing)
**Can start after**: Sub-Briefing 3

**Rationale**: These decisions define how briefs are created, consumed, and governed. They are prerequisites for the plan-writing protocol (#51) but can be built independently of Mission Command.

#### Sub-Briefing 7: Process Governance
**Decisions**: 35, 41, 48, 51, 52, 53, 54
**Intent**: Build the process-level governance -- incident escalation, plan-gate hook, fix-right decision tree, plan-writing protocol, Plan Writer role, governed drift prevention, harness improvement cycle.

**Internal connectivity**: High (54 is the hub linking to 35, 41, 48, 51)
**External dependencies**: All other sub-briefings. This is the capstone.
**Can start after**: Sub-Briefings 4, 5, 6

**Rationale**: These decisions depend on the frameworks being in place. #51 (plan-writing protocol) requires delegation (#4), channel (#22), running estimate (#50), intent skills (#39/#40), and the /brief skill (#45). #54 (harness improvement cycle) requires all frameworks for its orchestration pattern. This is the "how the whole system works together" cluster.

### Dependency Graph (Sub-Briefings)

```
         SB1 (Foundation)        SB2 (Platform)       SB3 (Intent)
              |                       |                     |
              v                       |                     |
         SB4a (Channel)              |                     |
              |                       |                     |
              v                       v                     |
         SB4b (Delegation)      (independent)              |
              |                                             |
              v                                             v
         SB4c (Coordination)                          SB6 (Mission Analysis)
              |                                             |
              v                                             |
         SB5 (Op Learning)                                  |
              |                                             |
              +---------------------------------------------+
              |
              v
         SB7 (Process Governance -- capstone)
```

### Parallel Execution Opportunities

| Wave | Sub-Briefings | Can run in parallel? | Estimated effort |
|------|--------------|---------------------|-----------------|
| Wave 1 | SB1 (Foundation), SB2 (Platform), SB3 (Intent) | Yes -- fully independent | Low-Medium each |
| Wave 2 | SB4a (Channel), SB5 partial (#10, #11 fixes) | Yes -- after SB1 | Medium |
| Wave 3 | SB4b (Delegation), SB6 (Mission Analysis) | Yes -- SB4b after SB4a, SB6 after SB3 | High, Medium |
| Wave 4 | SB4c (Coordination), SB5 remainder (#36 framework) | Yes -- after SB4b | High, High |
| Wave 5 | SB7 (Process Governance) | Sequential -- capstone | High |

### Each Sub-Briefing Needs Its Own Intent

Each sub-briefing should have a `meta.intent` with purpose, scope, and audience -- applying the same scope governance to briefings that the harness applies to files. This prevents the sub-briefing itself from expanding.

Example for Sub-Briefing 4a:

```json
{
  "purpose": "Build the channel infrastructure for inter-agent communication -- directory structure, message schemas, running estimate, collision prevention",
  "scope": "Decisions 22, 23, 46, 49, 50 only. NOT delegation protocol (SB4b). NOT staff functions (SB4c). NOT archival or learning loop (SB5). Channel infrastructure is the foundation; other sub-briefings build on it",
  "audience": "S3 (executing agent) building channel artifacts. Requires SB1 (namespace consolidation) to be complete"
}
```

---

## Summary

### What to Do First

**Option A: Execute the post-push bug briefing.** It is the only fully specified, immediately delegatable task. The briefing is complete with parallel sub-agent strategy and acceptance criteria. Estimated 30-45 minutes.

### What to Do Next

After the post-push bugs: **Option B** (file glossary terms + write intent skill updates). This closes 5-6 open threads and reduces context debt for future sessions.

Then **Option C** (.gitignore + workspace rule). This unblocks the entire namespace consolidation.

### What to Defer

- Artifact-roles framework (needs user decision, depends on glossary terms being filed)
- Registries directory move (R12, 59 files, needs its own plan)
- Observe-mode log review (R6, valuable but not urgent)
- Rules-json-guard hook (R9, depends on artifact-roles decision)

### What to Discard

Nothing should be discarded. Every thread opened in this session was legitimate. The failure was not in what was investigated but in how many investigations were active simultaneously. The scope-creep framework's discovery-vs-execution gate would have kept most of these as FINDINGs rather than threads -- preserving the knowledge without consuming the session.

### The Meta-Observation

This analysis is itself a scope-creep risk. The user asked for intelligence about scope creep. Producing a 3-part analysis with framework design, provenance research, and cluster decomposition is valuable -- but it is also opening new threads (framework design, sub-briefing creation, .gitignore fix) while the existing threads remain open. The correct application of the proposed framework would be: write this document as a FINDING, return to the declared session scope, and let the next session's S2 pick up the scope-creep governance thread.
