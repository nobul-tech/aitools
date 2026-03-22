# Q4 Investigation: Lifecycle of Operational Artifacts

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-18
**Question**: What is the lifecycle of operational artifacts (briefings, AARs, running estimates, investigation reports)? Where is "promoted to"?

---

## 1. Current State Analysis

### Where things actually live today

| Artifact | Current Location | Tracked? | How it got there |
|----------|-----------------|----------|------------------|
| Planning brief (JSON) | `plans/mission-command-briefing/planning-brief.json` | Yes | Created directly in plans/ |
| Handoff prompt | `plans/mission-command-briefing/handoff-prompt.md` | Yes | Created directly in plans/ |
| Investigation reports (S2) | `plans/mission-command-briefing/investigate-*.md` | Yes | Created directly in plans/ |
| Decision quality audit | `plans/mission-command-briefing/decision-quality-audit.md` | Yes | Created directly in plans/ |
| Known-state audit | `plans/mission-command-briefing/known-state-audit.md` | Yes | Created directly in plans/ |
| Research synthesis | `plans/mission-command-briefing/research-synthesis.md` | Yes | Created directly in plans/ |
| Delegation evolution | `plans/mission-command-briefing/delegation-evolution.md` | Yes | Created directly in plans/ |
| AAR (tool-ops plan) | `harvesting/2026-03-15_aar-tool-ops-plan.md` | Yes | Harvested from .scratch/ |
| AAR (duplicate) | `harvesting/2026-03-16_aar-tool-ops-plan.md` | Yes | Harvested from .scratch/ |
| Carry-forward design | `harvesting/2026-03-16_carry-forward-design.md` | Yes | Harvested from .scratch/ |
| Briefing analysis | `harvesting/2026-03-16_briefing-analysis.md` | Yes | Harvested from .scratch/ |
| Barrier analyses | `harvesting/2026-03-17_barrier-*.md` | Yes | Harvested from .scratch/ |
| Channel investigation | `harvesting/2026-03-17_channel-placement-investigation.md` | Yes | Harvested from .scratch/ |
| Workflow description | `harvesting/2026-03-17_workflow-description.md` | Yes | Harvested from .scratch/ |
| Running estimate | `.aitools/channel/session-uyZ7TELqpP/` | Gitignored | Created in session channel |
| Implementation plans | `plans/*.md` (top-level) | Yes | Created directly |

### The problem

Three categories of content are currently mixed into `plans/`:

1. **Plans** (execution documents): `governance-and-compliance-framework.md`, `datadog-log-integration.md`, `error-handling-audit.md`, etc. These are what `plans/` is FOR.

2. **Intelligence products** (S2 outputs): investigation reports, audits, research synthesis, decision quality audits. These FEED plans but are not plans themselves.

3. **Briefing artifacts** (structured decision documents): `planning-brief.json`, handoff prompts, delegation context. These DRIVE execution but are not plans themselves.

Additionally, `harvesting/` contains a parallel copy of several intelligence products (the same documents harvested from `.scratch/` AND manually placed in `plans/mission-command-briefing/`). This creates ambiguity about the canonical location.

---

## 2. Artifact Type Lifecycles

### 2.1 Briefings (Planning Briefs, Operational Briefs)

**Nature**: Structured decision documents that accumulate decisions, facts, and assumptions over multiple sessions. They drive execution by telling S3 what has been decided.

| Stage | Location | Tracked | Trigger |
|-------|----------|---------|---------|
| Draft | `.scratch/session-*/` | No | S2 begins structuring decisions from a session |
| Working | `briefings/<name>/` (proposed) | Yes | Decisions reach critical mass; brief becomes a carry-forward artifact |
| Active | `briefings/<name>/` (proposed) | Yes | Plan execution consumes the brief |
| Archived | `briefings/<name>/` (remains) | Yes | Plan execution completes; brief becomes historical record |

**Key property**: Briefings are living documents during planning. They are amended by FRAGORDs, updated by new investigations, and consumed by handoff prompts. They must be tracked (cross-machine carry-forward) and must survive session boundaries. They are NOT ephemeral.

**Promotion path**: Briefings do not get promoted further. They ARE the formalized product. Lessons learned from briefings feed into framework documentation (`reference/framework-*.md`) or rules (`.claude/rules/`).

### 2.2 AARs (After Action Reviews)

**Nature**: Structured post-execution analysis. A retrospective that captures what happened, what was planned, what differed, and what to improve.

| Stage | Location | Tracked | Trigger |
|-------|----------|---------|---------|
| Draft | `.scratch/session-*/` | No | Session produces significant work; agent writes AAR |
| Harvested | `harvesting/YYYY-MM-DD_aar-*.md` | Yes | SessionEnd hook harvests from .scratch/ |
| Consumed | Briefing references it | Yes | Next planning cycle reads the AAR as intelligence |
| Pruned or promoted | Pruning rules / reference/ | Yes | After 30 days: pruned if unused, promoted if referenced |

**Key property**: AARs are session products -- they capture what ONE session did. They belong in the harvesting pipeline because they start in scratch and need evaluation before permanent placement. An AAR that reveals a framework-level insight gets promoted into a `reference/incident-*.md` or `reference/framework-*.md` file.

**Promotion path**: `scratch` -> `harvesting/` -> (if framework-significant) `reference/` or feeds a briefing decision.

### 2.3 Plans (Implementation Plans)

**Nature**: Execution documents that consume briefings. They specify what to build, in what order, with what constraints.

| Stage | Location | Tracked | Trigger |
|-------|----------|---------|---------|
| Draft | `plans/` directly | Yes | S3 receives handoff prompt and brief |
| Active | `plans/*.md` | Yes | Execution begins |
| Complete | `plans/*.md` (remains) | Yes | All steps executed, AAR written |

**Key property**: Plans are created directly in their permanent home. They do not start in scratch because they are never ephemeral -- a plan is a commitment to execute. Plans REFERENCE briefings, they do not CONTAIN them.

**Promotion path**: Plans do not get promoted. Lessons from plan execution feed AARs, which feed future briefings.

### 2.4 Investigation Reports (S2 Products)

**Nature**: Intelligence products -- audits, research, barrier analyses, transcript investigations. They answer specific questions.

| Stage | Location | Tracked | Trigger |
|-------|----------|---------|---------|
| Draft | `.scratch/session-*/` | No | S2 subagent produces investigation during session |
| Harvested | `harvesting/YYYY-MM-DD_investigate-*.md` | Yes | SessionEnd hook harvests |
| Consumed | Briefing references it; decisions updated | Yes | S2/S3 reads the report and updates the brief |
| Pruned or promoted | Pruning rules / reference/ | Yes | After 30 days: pruned if consumed, promoted if reusable |

**Key property**: Investigation reports are tactical -- they answer a question for a specific planning cycle. Most are consumed (their findings absorbed into a briefing decision) and then prunable. A few reveal reusable patterns and get promoted to `reference/`.

**The current problem**: Some investigation reports (`investigate-*.md`) were placed DIRECTLY in `plans/mission-command-briefing/` rather than going through the harvesting pipeline. This happened because they were produced as part of the briefing preparation, not as standalone session artifacts. This is the lifecycle gap the user identified.

**Promotion path**: `scratch` -> `harvesting/` -> consumed by briefing -> pruned. OR `scratch` -> `harvesting/` -> `reference/` (if reusable).

### 2.5 Running Estimates

**Nature**: Carry-forward state between sessions. Consolidated situation assessment.

| Stage | Location | Tracked | Trigger |
|-------|----------|---------|---------|
| Active | `.aitools/channel/running-estimate.json` | Yes | Created/updated by every session |
| Archived | Superseded by new version | N/A | Each update replaces the prior |

**Key property**: Running estimates are unique -- they are always active, always tracked, always at a fixed path. They do not go through the harvesting pipeline because they are not session artifacts. They are state, not products.

**Promotion path**: No promotion. The running estimate IS the operational state. Insights from it feed briefings.

---

## 3. Barrier Analysis

### Option A: `briefings/` as new top-level directory alongside `plans/`

**Structure**:
```
aitools/
├── briefings/
│   └── mission-command/
│       ├── planning-brief.json
│       ├── handoff-prompt.md
│       └── (investigation reports stay in harvesting/)
├── plans/
│   ├── governance-and-compliance-framework.md
│   └── mission-command-and-platform-engineering.md  (references briefings/)
├── harvesting/
│   └── (AARs, investigation reports, tactical artifacts)
└── reference/
    └── (frameworks, specs, permanent docs)
```

**Barriers to success**:
- None significant. Clean separation of concerns.
- Migration is straightforward: move `plans/mission-command-briefing/` content.
- References in handoff-prompt.md and other files need updating.

**Barriers to failure**:
- Does NOT solve the problem of investigation reports being placed directly in the briefing directory. A briefing directory could still accumulate intelligence products if the rule is not clear about what lives there.
- Needs clear rule: briefings/ contains ONLY structured decision documents (brief JSON, handoff prompts, delegation context). Intelligence products go through harvesting/.

**Assessment**: Strong option. Clean taxonomy, clear separation from plans, matches the user's stated intent ("there should be a briefings folder"). The only risk is scope creep -- intelligence products sneaking into briefings/ instead of going through harvesting/.

### Option B: Rename `plans/` to `briefings/` (briefings subsume plans)

**Structure**:
```
aitools/
├── briefings/
│   ├── mission-command/
│   │   ├── planning-brief.json
│   │   └── handoff-prompt.md
│   ├── governance-and-compliance-framework.md  (was a "plan")
│   └── datadog-log-integration.md              (was a "plan")
└── reference/
```

**Barriers to success**:
- **Semantic confusion**: Implementation plans and decision briefs are fundamentally different artifact types. A "plan" says WHAT to build and HOW. A "briefing" says WHAT was decided and WHY. Conflating them loses the distinction.
- **Existing references**: Many files reference `plans/` paths. Mass rename.
- **CLAUDE.md project structure**: `plans/` is documented as a top-level directory.

**Barriers to failure**:
- Eliminates the misplacement problem by having one directory for everything operational.

**Assessment**: Weak option. The semantic conflation is the dealbreaker. Plans and briefings serve different functions in the operational cycle. Merging them recreates the current problem in a renamed directory.

### Option C: Briefings live inside `.aitools/` (workspace namespace)

**Structure**:
```
aitools/
├── .aitools/
│   ├── briefings/
│   │   └── mission-command/
│   │       ├── planning-brief.json
│   │       └── handoff-prompt.md
│   ├── channel/
│   └── scratch/  (gitignored)
├── plans/
└── reference/
```

**Barriers to success**:
- **Violates the workspace governing principle**: `.aitools/` is defined as "harness capabilities that persist across sessions and machines." Briefings are project-specific content, not harness capabilities. The workspace rule (`aitools-workspace.md`) says `.aitools/` holds channel, scratch, and harvesting -- all are capabilities the harness provides to ANY project. A briefing is specific to the aitools project.
- **Visibility**: `.aitools/` is a hidden directory. Briefings are high-visibility operational documents that drive execution. Hiding them is wrong.
- **Scope**: `.aitools/` is designed to be portable -- the same structure in any project the harness touches. Briefings are unique to the project.

**Barriers to failure**:
- Would consolidate operational state (running estimate + briefings) in one namespace.

**Assessment**: Rejected. Briefings are project content, not harness capabilities. The workspace namespace has a clear governing principle and briefings violate it.

### Option D: Unified `operations/` directory

**Structure**:
```
aitools/
├── operations/
│   ├── briefings/
│   │   └── mission-command/
│   │       ├── planning-brief.json
│   │       └── handoff-prompt.md
│   ├── plans/
│   │   ├── governance-and-compliance-framework.md
│   │   └── mission-command-and-platform-engineering.md
│   └── aars/
│       └── (promoted from harvesting/)
├── harvesting/
│   └── (pipeline -- artifacts in evaluation)
└── reference/
    └── (permanent documentation)
```

**Barriers to success**:
- **Over-engineering**: Adds a nesting level that does not buy much over Option A. `operations/briefings/` vs `briefings/` -- the extra directory adds hierarchy without adding clarity.
- **AARs already have a home**: AARs belong in the harvesting pipeline. Pulling them out into `operations/aars/` creates a parallel lifecycle that conflicts with the harvesting framework.
- **Migration scope**: Moving plans/ into operations/plans/ touches every reference to plans/*.

**Barriers to failure**:
- Would centralize all operational artifacts under one umbrella.
- Military doctrine alignment (operations center metaphor).

**Assessment**: Mixed. The concept is sound (group operational artifacts), but the execution adds unnecessary hierarchy and conflicts with the existing harvesting lifecycle. The military doctrine alignment is appealing but the harness already has clear lifecycles for AARs (harvesting) and plans (top-level). Adding a wrapper directory does not improve those lifecycles.

---

## 4. Recommended Decision

### Option A: `briefings/` as a new top-level directory

**Rationale**:

1. **Matches the user's stated intent**: "there should be a briefings folder" -- the user identified the problem and named the solution.

2. **Clean taxonomy**: The lifecycle has four distinct permanent homes, each with a clear purpose:
   - `briefings/` -- structured decision documents that DRIVE execution (briefs, handoff prompts, delegation context)
   - `plans/` -- execution documents that CONSUME briefings (implementation plans)
   - `harvesting/` -- pipeline for tactical artifacts in evaluation (AARs, investigation reports, code)
   - `reference/` -- permanent documentation (framework docs, specs, registries)

3. **Preserves existing lifecycles**: Harvesting, plans, and reference all keep their current roles. Only the briefing artifacts move.

4. **Clear promotion path for all artifact types**:
   - **Briefing**: created directly in `briefings/<name>/` (not ephemeral)
   - **Plan**: created directly in `plans/` (not ephemeral)
   - **AAR**: `scratch` -> `harvesting/` -> consumed by briefing -> pruned (or promoted to `reference/`)
   - **Investigation report**: `scratch` -> `harvesting/` -> consumed by briefing -> pruned (or promoted to `reference/`)
   - **Running estimate**: always at `.aitools/channel/running-estimate.json`

5. **Answers the user's lifecycle question**: "a lot of this stuff starts in either scratch or channel first by design, but how do we define where these artifacts live?" The answer is: scratch and channel are where artifacts are BORN. Harvesting is where they are EVALUATED. Briefings, plans, and reference are where they LIVE when formalized. Each has clear entry criteria.

### What lives in `briefings/`

| Artifact | Why it belongs | Why it does NOT belong in plans/ |
|----------|---------------|--------------------------------|
| Planning brief (JSON) | Structured decisions that drive plan writing | It is not a plan -- it is intelligence that plans consume |
| Handoff prompt | Execution instructions for S3, references the brief | It is delegation context, not an implementation plan |
| Delegation context | How the brief was produced, for S3 reference | It is process documentation, not execution steps |

### What does NOT live in `briefings/`

| Artifact | Where it belongs | Why |
|----------|-----------------|-----|
| Investigation reports | `harvesting/` (pipeline) | They are session products, need evaluation before permanent placement |
| AARs | `harvesting/` (pipeline) | They are session products, go through harvesting lifecycle |
| Research synthesis | `harvesting/` (pipeline) | Session product consumed by briefing decisions |
| Decision quality audits | `harvesting/` (pipeline) | Session product consumed by briefing improvements |
| Cross-platform audits | `harvesting/` (pipeline) | Session product consumed by briefing facts |

### Rule needed

A `briefings/` directory requires a governing rule (`.claude/rules/briefings.md` or similar) that specifies:
- What artifacts live there (structured decision documents only)
- What does NOT live there (intelligence products -- those go through harvesting)
- Naming convention for briefing directories (e.g., `briefings/<plan-name>/`)
- Relationship to plans (briefings DRIVE plans, plans REFERENCE briefings)
- Lifecycle states (draft, working, active, archived)

### Migration

Move from `plans/mission-command-briefing/` to `briefings/mission-command/`:
- `planning-brief.json` -- moves (this is the briefing)
- `handoff-prompt.md` -- moves (this is delegation context for the briefing)
- `delegation-context.md` -- moves (same)
- `delegation-evolution.md` -- stays in harvesting (it is a session product, already there as `harvesting/2026-03-16_delegation-evolution.md`)
- `investigate-*.md` (4 files) -- stay in harvesting (session products, several already there)
- `decision-quality-audit.md` -- stays in harvesting (session product, already there)
- `research-synthesis.md` -- stays in harvesting (session product, already there)
- `cross-platform-full-audit.md` -- stays in harvesting (session product, already there)
- `known-state-audit.md` -- stays in harvesting (session product)
- `intent-approval-evolution.md` -- stays in harvesting (session product, already there)
- `task-rebuild-brief.py` -- stays in harvesting (code artifact)

The duplicates between `plans/mission-command-briefing/` and `harvesting/` should be resolved: harvesting is the canonical location for session products. The copies in `plans/mission-command-briefing/` were placed there as convenience references for the briefing preparation, but they belong in harvesting.

---

## 5. Summary: The Full Lifecycle

```
Session Work (ephemeral)
  .scratch/session-*/          -- born here, gitignored
  .aitools/channel/session-*/  -- messages (SITREPs, FINDINGs), gitignored
       |
       v
Evaluation Pipeline (tracked)
  harvesting/                  -- harvested from scratch by SessionEnd hook
  .aitools/channel/running-estimate.json  -- carry-forward state (special: no harvesting pipeline)
       |
       v
Permanent Homes (tracked, each with distinct purpose)
  briefings/<name>/            -- structured decision documents (briefs, handoff prompts)
  plans/                       -- implementation plans (consume briefings)
  reference/                   -- framework docs, specs, registries (promoted from harvesting)
  .claude/rules/               -- behavioral rules (promoted from reference or created directly)
```

Each arrow is a promotion gate with clear criteria:
- **scratch -> harvesting**: SessionEnd hook classifies; non-ephemeral files harvested
- **harvesting -> briefings**: Decision reaches critical mass; manually promoted
- **harvesting -> reference**: Reusable pattern identified; manually promoted
- **harvesting -> pruned**: 30-day rule, no references, not flagged "keep"
- **briefing -> archived**: Plan execution completes; briefing becomes historical
