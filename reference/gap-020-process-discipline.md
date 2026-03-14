# Gap #20: No Process Discipline Rule

**Intent**: **Purpose**: Capture the full discovery context for gap #20
— why process discipline is needed, what discipline it maps to, and
how we propose to adopt it. **Scope**: The discovery and research that
produced gap #20. NOT the implementation of the solution (that will be
tracked by the plan). **Audience**: The agent that picks up this gap
for resolution.

## Discovery

Session: 2026-03-14.

During governance plan step 4 prerequisite work (SubagentStart hook),
the agent proposed pulling step 7 (/aitools-dev skill) forward to
before step 4. The justification was "the skill is small." The user
identified this as a process deviation — bypassing the plan's
sequential dependencies without formally amending the plan first.

## State Audited

- `@CLAUDE.md` design principles — three-layer governance, ambiguity
  is a defect, specs vs state. None address plan adherence or process
  discipline.
- `@.claude/rules/gap-governance.md` — tracks defects, not process.
  The decision tree classifies findings but doesn't govern how plans
  are followed.
- `@.claude/rules/plan-execution.md` — covers code batch mechanics
  (sub-agent execution pattern). Does not address plan sequencing or
  deviation protocols.
- `/planning` skill — covers plan creation strategy (context budgets,
  batch sizing, session flow). Does not address adherence to existing
  plans.
- `/optimize-plan` skill — covers plan review (stale sections,
  leverage map). Does not address process discipline during execution.

None of these address: what constitutes a process deviation, when
resequencing is acceptable, or how to formally amend a plan.

## Discipline: Process Management

This maps to process management — specifically:

- **Process deviation** (ISO/quality management): Doing something
  outside an established procedure. Deviations require documentation
  and justification. The procedure exists for a reason; bypassing it
  without amending it first means the deviation is invisible to
  future sessions.
- **Change management protocols**: Amend first, execute second. The
  plan IS the procedure. Changing the execution order without
  amending the plan is an undocumented change.
- **Double-loop learning** (Argyris): The agent's proposal to pull
  step 7 forward revealed that the framework itself lacked a concept
  (process discipline). The fix isn't "don't pull steps forward" —
  it's "define when and how pulling steps forward is legitimate."

## Suggested Resolution

Create a user-level rule (`~/.claude/rules/process-discipline.md`)
covering:
- **Plan adherence**: Steps are sequential for a reason. Dependencies
  between steps are intentional.
- **Process deviation**: Definition — executing outside the plan's
  sequence without formal amendment. Documentation requirement —
  what was deviated and why.
- **Plan amendment protocol**: Amend the plan first, execute second.
  Present the amendment with rationale. The plan is a protected file.
- **Prerequisite pull-forward**: When a later step is genuinely needed
  earlier, amend the plan with rationale before executing.

Add a design principle to `@CLAUDE.md`.

Alternative: extend `@.claude/rules/gap-governance.md` with a process
section. But process discipline is broader than gap governance and
applies across all projects, so a separate user-level rule is
preferred.
