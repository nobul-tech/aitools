# Incident Investigation

**Intent**: **Purpose**: Document the framework for investigating what
went wrong, finding root causes, and preventing recurrence. **Scope**:
What safety engineering principles we adopted and why. NOT the
operational investigation steps (those are in the `/investigate` skill).
**Audience**: Agents encountering incidents, framework adoption work.

## Source Discipline

Safety engineering:
- **5 Whys** (Toyota Production System) — iterative root cause
  analysis until reaching a systemic cause
- **Swiss cheese model** (James Reason) — multiple defense layers each
  have holes; incidents occur when holes align
- **Barrier analysis** — evaluate whether a proposed fix would have
  actually prevented the incident

## How We Adopted It

- **Full incident lifecycle** → 8 steps from detection through
  follow-up in the `/investigate` skill
- **Contributing factors** → Swiss cheese model applied to our three
  governance layers (prevention, detection, audit)
- **Corrective action types** → behavioral (coaching), structural
  (hooks/rules/skills), environmental (config/tool changes).
  Escalation: behavioral → structural when coaching doesn't hold.
- **Barrier analysis** → governance plan decision #17: replay the
  incident with the proposed fix; if it wouldn't have changed the
  outcome, it addresses a different failure class
- **Recurrence tracking** → same root cause 3+ times = wrong fix.
  Escalate from behavioral to structural.

## How It's Maintained

- Effectiveness tracker in dotprofile repo logs incidents
- `/audit` skill checks for coaching items with 3+ recurrences
- Corrective actions verified in follow-up sessions
- `/investigate` skill teaches the methodology to every session

## Implementing Artifacts

- `@shared/skills/investigate/SKILL.md` (operational skill)
- `@plans/governance-and-compliance-framework.md` decision #17
- Effectiveness tracker in dotprofile repo (incident data)

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Gap governance: `@reference/framework-gap-governance.md`
