---
name: optimize-plan
description: "Review and improve an existing plan file. Use when a plan needs re-evaluation after new discoveries, scope changes, or multiple implementation sessions. Detects stale sections, dependency issues, leverage opportunities, and scope drift."
---

## Purpose

Plans evolve. Each implementation session surfaces new information that
may invalidate assumptions, change dependencies, or shift priorities.
This skill provides a structured re-evaluation of an existing plan file
against current state.

This is NOT a one-shot review — invoke periodically after major batches,
mid-session discoveries, or when the plan feels unwieldy.

## When to use

- After completing a batch of implementation steps
- When new decisions change the scope of remaining work
- When a plan has been revised multiple times and may have internal drift
- When starting a new session on a multi-session plan
- When the user asks to review or optimize a plan

## Process

### Step 1: Load current state

Read the plan file. Then read these for comparison:
- `reference/known-gaps.json` — are gaps referenced in the plan still open?
- `ROADMAP.md` — does the plan's scope match the roadmap entry?
- Recent git log (`git log --oneline -20`) — what changed since the plan
  was last updated?
- Any rules the plan references — are they still current?

### Step 2: Stale section detection

For each section of the plan:
- Do counts match? (e.g., "30 skills" in one place, "41" in another)
- Are "done" markers current? (steps marked done that aren't, or vice versa)
- Do cross-references still resolve? (deleted files, renamed sections)
- Are any decisions superseded by later work?

Flag each stale item with what's wrong and what the current state is.

### Step 3: Dependency analysis

Map what depends on what:
- Which implementation steps block other steps?
- Have completed steps changed the requirements for upcoming steps?
- Are there circular dependencies or steps that should be reordered?

Present as: "Step N depends on Step M. Step M was completed but its
scope changed — Step N may need revision."

### Step 4: Leverage assessment

For each remaining step, estimate downstream impact:
- How many other steps does this unblock?
- How many sessions will use this once built?
- Does this reduce friction for all future work or just one task?

Present as a leverage map — not a priority list, but "if you build X,
it unblocks Y and Z" visibility.

### Step 5: Scope assessment

- Is this plan still one coherent effort, or has it grown into multiple
  independent workstreams?
- Are there sections that could be split into their own plan?
- Is the plan's title/description still accurate?

### Step 6: Missing content check

- Were decisions made in conversation but not captured in the plan?
- Are there foundational decisions that should be numbered but aren't?
- Are there gaps filed in known-gaps.json that should be referenced
  in the plan's Open Questions section?

### Step 7: Present findings

Output a structured report:

```markdown
## Plan Review: <plan name>

### Stale Sections
- <section>: <what's wrong> → <current state>

### Dependencies
- <step N> depends on <step M> (status: <ok|changed|broken>)

### Leverage Map
- <step>: unblocks <N> downstream steps (<list>)

### Scope Assessment
- Coherent / Should split: <rationale>

### Missing Content
- <decision/gap not captured>

### Recommended Actions
1. <specific action>
2. <specific action>
```

## Context-window awareness

Plan review depth scales with available context:
- **1M context (Opus extended)**: Read all referenced rules and reference
  files. Full cross-reference validation. Deep dependency analysis.
- **200k context (Sonnet/Opus standard)**: Read the plan + known-gaps.json
  + git log. Spot-check cross-references.
- **100k context (Haiku)**: Read only the plan. Surface-level consistency
  check.

Check context budget before loading reference files. Use `/context` if
available.

## Platform awareness

This skill does NOT enforce cross-platform checks. Platform coverage
is a project-specific concern. If the plan is for a cross-platform
project, the project's planning skill (e.g., `/aitools-planning`)
handles platform-specific quality checks.

If scripts are modified but only one platform is shown, flag it as a
contextual question: "Scripts modified but only one platform shown.
Intentional for this project?"
