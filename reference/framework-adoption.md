# Framework Adoption

**Intent**: **Purpose**: Document the process for adopting concepts
from established disciplines into the harness, and the cross-reference
convention for connecting framework artifacts. **Scope**: The
discovery-to-continuation cycle (DTCC), its trigger, guidance for
recognizing disciplines, and the cross-reference convention. NOT the
harness definition (see `@reference/harness.md`). NOT the registry
convention (see `@reference/framework-three-layer-governance.md`).
NOT the framework registry (see `@reference/framework-registry.json`).
**Audience**: Agents encountering ambiguities, agents adopting new
frameworks, agents creating framework artifacts, the `/gap` skill.

## The Discovery-to-Continuation Cycle

This cycle carries you from "something is missing" through to "back
on track." Nine steps — steps 1-6 produce gap context, steps 7-9 are
execution tracked by plans and commits.

### Trigger: ambiguity

The cycle begins when an agent encounters a decision point where the
harness doesn't provide explicit guidance on how to proceed. This can
happen at any time — during planning, execution, conversation, code
review, validation, debugging, or when a bug surfaces an unaddressed
assumption.

The source may be a gap in the harness artifacts, a gap in the
governance frameworks, a bug, or context rot. Regardless of cause,
the trigger is the same: a decision point without explicit instructions
that would otherwise lead to an assumption.

The assumption is the failure mode. When an agent assumes instead of
surfacing the ambiguity, the result may be correct by coincidence but
wrong by process — and invisible to future sessions that inherit the
outcome without knowing it was never deliberated.

Not every ambiguity triggers the full nine steps. If an existing spec
addresses the situation but the code deviates, that's a simple gap —
steps 1-3, file it, move on. The full cycle (steps 4-9) engages when
no spec exists and the resolution requires adopting concepts from an
established discipline.

### 1. Record context

Before investigating the ambiguity, capture what you were doing when
it surfaced. This becomes the `discoveryContext` field in the gap
entry:
- What plan step or task were you executing?
- What goal were you working toward?
- What specific action or decision triggered the ambiguity?
- Session date and archive reference if available

This context is essential for the consumer — they need to understand
the situation that revealed the gap, not just the gap itself.

### 2. Audit existing state

Search the harness for anything that addresses this decision point.
The ambiguity may be real (nothing covers it) or apparent (something
covers it but you didn't find it, or it's unclear). Check:
- `@.claude/rules/frameworks.md` — does an existing framework govern
  this class of decision?
- `@reference/framework-registry.json` — load via `/frameworks` skill
- `@reference/known-gaps.json` — has this already been filed?
- Rules that might address it — search `.claude/rules/` and
  `~/.claude/rules/`
- Reference files, plan sections, design principles in `@CLAUDE.md`

Record every artifact you checked and what it said (or didn't say).
This becomes the `expected` field. If you find a spec that addresses
the situation, cite it — the ambiguity may resolve here. If nothing
addresses it, write: "No spec exists for: [topic]."

### 3. Characterize the deficiency

Separate what you observed from what you interpret:
- **Observation** (`observation` field): concrete facts only. Quote
  specific text, cite file:line, name specific behaviors. "Agent
  proposed pulling step 7 forward" — not "the process is broken."
- **Expected** (`expected` field): what the spec says should happen,
  or the explicit statement that no spec exists. Cite file:section.
- **Impact** (`impact` field): what breaks, degrades, or is at risk.
  Name the affected workflow and who is affected. Be concrete.

If you cannot clearly separate observation from interpretation, you
may not understand the deficiency well enough to proceed. Ask the
user for help.

### 4. Recognize the discipline

Check whether this deficiency maps to an established field of
practice — one where significant prior work exists. Consult the
framework registry (`@reference/framework-registry.json`) for
disciplines already recognized. If a discipline matches:
- Name it in the `discipline` field
- Proceed to step 5

If no discipline matches:
- The deficiency may be novel, or you may not recognize the discipline
- Ask the user — they may recognize the field
- If truly novel, proceed to step 6 with a harness-native solution
  (new rule, new convention) rather than adopting from a discipline

Simple code deviations (bash script missing a function that PS1 has)
skip steps 4-6 entirely — file the gap with steps 1-3 and move on.

### 5. Research frameworks

For the recognized discipline, identify specific frameworks, models,
or practices that address this class of problem:
- Name them specifically (e.g., "double-loop learning (Argyris)",
  not "some learning theory")
- Describe what they say in enough detail that the consumer can
  evaluate them without prior knowledge of the discipline
- Note which aspects are relevant to our situation and which aren't
- Record findings in the `frameworks` field

The goal is to give the consumer a starting point for learning, not
an exhaustive literature review. Name 1-3 key frameworks with enough
context to be actionable.

### 6. Design the adaptation

Propose how the relevant frameworks would map into our harness.
This is the creative step — translating external concepts into
concrete artifacts:
- Which harness level? (platform, configuration, orchestration,
  managed tools, frameworks — see `@reference/harness.md`)
- Which artifact type? (rule, skill, hook, reference file, design
  principle, JSON registry entry)
- What would the artifact contain?
- Are there alternatives? List them with trade-offs.
- Record in the `suggestedResolution` field

This is a suggestion, not a commitment. The consumer may be in a
different context with different priorities. Always list options
when the path isn't obvious.

### 7. Implement

Build the artifacts designed in step 6. This step is tracked by
plans, commits, and pull requests — not the gap entry. The gap's
`linked` field points to the tracking item.

Follow existing conventions:
- Protected files require review (`@.claude/rules/sources-of-truth.md`)
- Intent statements require user approval
- New framework files follow the cross-reference convention (above)
- New registry entries follow the registry convention
  (`@reference/framework-three-layer-governance.md`)

When creating a skill as part of a framework, create three artifacts
together — never one without the others:

1. **Skill** (SKILL.md) — the governed process
2. **Trigger directive** in the governing rule — when to invoke
3. **Detection hook spec** — what to detect when the process is bypassed

The hook may not be built immediately (hook infrastructure is
incremental), but the spec must be designed at adoption time. Track
unbuilt hooks via `/gap` skill.

### 8. Integrate

Wire the new artifacts into the three-layer governance:
- **Prevention**: add rules, update skills, update project claude
- **Detection**: add or update hooks
- **Audit**: update `/audit` skill scope, add to check scripts

Update the framework registry if a new framework was created.

### 9. Continue

Resume the work that was interrupted by the discovery. Before
continuing, assess whether the discovery changed the plan:
- Does the plan's sequencing still hold?
- Were any assumptions invalidated?
- Do other plan steps need amendment?

If the harness itself changed (new principle, new framework, new
convention), the plan that was in progress may need to account for
that. This is what makes it double-loop: not just fixing the problem,
but recognizing that the framework evolved and downstream work may
need adjustment.

## Disciplines

A discipline is an established field of practice where significant
prior work exists on how to solve a class of problems. When the
DTCC reaches step 4 (Recognition), you're looking for a discipline
that owns the problem you've found.

Not every gap maps to a discipline. Simple code deviations are just
bugs. Framework-level gaps — where no spec exists for an entire class
of decisions — map to disciplines.

How to recognize a discipline:
- The problem class has a name in industry or academia
- Multiple frameworks, models, or practices exist for it
- People have written books, standards, or methodologies about it
- You can find prior art that directly informs your adaptation design

The framework registry (`@reference/framework-registry.json`,
accessible via `/frameworks` skill) tracks which disciplines have
been recognized and which frameworks were adopted from them. Each
framework entry includes its source discipline and key concepts.

When you recognize a new discipline not yet in the registry, document
it as part of the framework adoption (step 8: Integrate).

## Cross-Reference Convention

Every framework has implementing artifacts (rules, skills, hooks,
reference files). The cross-references between them must be explicit
and bidirectional:

- **Framework reference file** → lists all implementing artifacts
  (rules, skills, hooks) with `@` references
- **Rule** → references its framework file
- **Skill** → references its framework file in Cross-References section
- **Hook** → references its framework in header comment

Naming:
- Framework reference files use concept names:
  `framework-<concept>.md` (e.g., `framework-incident-investigation.md`)
- Skills use user mental model names:
  `/investigate` (not `/incident-investigation`)
- The names will differ — the cross-references connect them

This lets a reader starting from any artifact find the framework
it implements, and a reader starting from the framework find all
its artifacts.

## Cross-References

- Harness definition: `@reference/harness.md`
- Framework registry: `@reference/framework-registry.json`
- Framework rule: `@.claude/rules/frameworks.md`
- Gap governance: `@.claude/rules/gap-governance.md`
- Governed vocabulary: `@reference/framework-governed-vocabulary.md`
- Intent documentation: `@reference/framework-intent-documentation.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
