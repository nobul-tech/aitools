---
paths:
  - scripts/**
  - deploy/**
  - shared/**
  - reference/**
  - plans/**
---

## Tool Evaluation (this repo)

**Intent**: **Purpose**: Govern how install methods are chosen and
how tool health is maintained for all managed tools. **Scope**:
Evaluation gates, principle enforcement, and skill delegation.
NOT the evaluation process (`/tool-eval` skill). NOT flag criteria
(`/tool-eval` skill). NOT registry data (`/tool-registry` skill).
NOT lifecycle gates (`@.claude/rules/tool-lifecycle.md`).
**Audience**: Every agent making install method decisions.

### Governing principle

aitools exists to give developers the best possible cross-platform
tooling experience. Every managed tool is first-class — there are
no second-class tools. An agent that recommends a degraded install
method — system-bundled, unverified, stale — has violated this rule.
An agent that assumes a limited use case to justify a lesser method
has the evaluation backwards. Requirements determine the method,
not assumptions about how the tool will be used.

### Evaluation principles (ranked)

All install method decisions MUST follow these, in order.
Higher-ranked override lower when they conflict. Rationale and
detail: `@reference/tool-evaluation-criteria.md`.

1. Official endorsement
2. Verified provenance and security
3. Latest stable version
4. Cross-platform delivery — don't rebuild what exists
5. Same upstream distribution across platforms
6. Automation and deployment
7. Maintenance health
8. Build time

### Gates

- All evaluations MUST go through the `/tool-eval` skill
- Every install method decision MUST be documented in
  `reference/evaluations/`
- Every tool MUST have per-platform health flags — `/tool-eval`
  skill defines the criteria
- Red flags MUST have a linked evaluation with migration plan
- Yellow flags MUST be reviewed within 90 days

### Cross-references

- Evaluation process and flag criteria: `/tool-eval` skill
- Registry access: `/tool-registry` skill
- Evaluation criteria detail: `@reference/tool-evaluation-criteria.md`
- Discovery process: `@reference/tool-evaluation-playbook.md`
- Lifecycle gates: `@.claude/rules/tool-lifecycle.md`
