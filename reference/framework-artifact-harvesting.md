# Artifact Harvesting

**Intent**: **Purpose**: Document the framework for harvesting,
evaluating, and promoting reusable artifacts produced during
development sessions. **Scope**: Source discipline (DA reuse
engineering), adaptation to our harness, the harvesting lifecycle
concept, and KPI design. NOT the harvesting governance
(`@.claude/rules/artifact-harvesting.md`). NOT the harvesting process
(`/harvest` skill). NOT the ephemeral scratch pattern.
**Audience**: Agents designing harvesting improvements, framework
adoption work.

## Source Discipline

Reuse engineering (Disciplined Agile) — the practice of deliberately
identifying, extracting, generalizing, and publishing reusable assets
from working code. PMI/DA defines the lifecycle: identify → obtain →
generalize → validate → publish.

Extended with concepts from:

- **Staging pipeline** (Linux kernel `drivers/staging/`): code that
  works but isn't mainline quality sits in staging with an explicit
  expectation — promote or remove. No permanent parking lot.
- **Toil automation** (Google SRE): manual/repetitive/automatable
  work follows a progression: runbook → script → tool → platform.
  Harvested scripts are at the "script" stage, promotion moves them
  toward "tool."
- **Tactical-to-strategic programming** (Ousterhout): code written
  to solve an immediate problem (tactical) may deserve investment
  to become a proper abstraction (strategic). The harvesting lifecycle
  is the bridge.

## How We Adopted It

- **Two-directory pattern** → `.scratch/` (ephemeral, gitignored) and
  `harvesting/` (tracked, evaluated). Clean separation of throwaway
  from potentially reusable.
- **SessionEnd harvesting** → hook classifies `.scratch/` contents
  and moves artifacts to `harvesting/` with manifest metadata.
  Automation prevents "forgot to save that script."
- **SessionStart evaluation** → hook audits `harvesting/` inventory,
  auto-prunes stale artifacts, identifies promotion candidates.
  Automation prevents "forgot to review what we harvested."
- **Generalization review** → AI-powered analysis via `/harvest review`
  compares artifacts against harness inventory to find promotion
  opportunities. Bridges tactical → strategic.
- **KPI-driven lifecycle** → Datadog metrics track harvesting flow:
  inventory, age distribution, promotion rate, generalization actions.
  Data-driven decisions about what to keep, promote, or prune.

## How It's Maintained

- Rule in `@.claude/rules/artifact-harvesting.md` governs criteria
- `/harvest` skill implements the process
- SessionEnd and SessionStart hooks automate the pipeline
- `/harvest review` triggers generalization analysis
- KPIs shipped to Datadog for trend visibility

## Implementing Artifacts

- `@.claude/rules/artifact-harvesting.md` (governance)
- `.claude/skills/harvest/SKILL.md` (process)
- `harvesting/` (tracked artifact directory)
- `/harvest` skill governs manifest data
- `shared/hooks/harvest-session.sh` (SessionEnd/SessionStart automation)

## Cross-References

- Framework registry: `/frameworks` skill
- Governed data access: `@.claude/rules/governed-data-access.md`
- Ephemeral scratch: `/scratch` skill
- Datadog integration: `plans/datadog-log-integration.md`
