# Tool Lifecycle

**Intent**: **Purpose**: Document the framework for evaluating,
approving, integrating, maintaining, and health-tracking managed tools.
**Scope**: What software asset management principles we adopted and
why. NOT the evaluation requirements (`@.claude/rules/tool-evaluation.md`).
NOT the operational checklist (`@.claude/rules/tool-lifecycle.md`).
NOT tool data (use `/tool-registry` skill). **Audience**: Agents
onboarding new tools, framework adoption work.

## Source Discipline

Software asset management — lifecycle phases, approval gates,
deprecation paths. Tools are assets with costs (maintenance, security
surface, PATH complexity) and benefits. The lifecycle gates cost
evaluation before committing to benefits.

Extended with provenance verification (supply chain security) and
health flags (continuous monitoring) to address the reality that
tools degrade over time — vendors deprecate runtimes, maintainers
go inactive, install methods change upstream.

## How We Adopted It

- **5-phase lifecycle** → Discovery, Evaluation, Approved, Integrated,
  Deprecated
- **Phase 2 gate** → hard stop requiring user approval before
  integration code. Prevents sunk-cost commitment.
- **Per-platform status** → tools approved on one platform may still
  be evaluating on another
- **Install method discovery** → upstream install commands verified
  via official docs. Process in `/tool-eval` skill
- **Health flags** → continuous monitoring adapted as per-platform
  health indicators. Criteria in `/tool-eval` skill, requirements
  in `@.claude/rules/tool-evaluation.md`
- **Provenance verification** → supply chain security adapted as
  install method traceability. Process in `/tool-eval` skill
- **Evaluation provenance** → decision rationale preserved in
  `reference/evaluations/`. Process in `/tool-eval` skill

## How It's Maintained

- Onboarding checklist in `@.claude/rules/tool-lifecycle.md`
- Evaluation principles in `@.claude/rules/tool-evaluation.md`
- Post-push checks verify tool command availability and version
- `/tool-registry` skill provides governed access to tool data
- `/tool-eval` skill runs evaluations and updates health flags
- Install methods re-verified via Chrome DevTools skill when modifying
  setup scripts

## Implementing Artifacts

- `@.claude/rules/tool-lifecycle.md` (operational rule + checklist)
- `@.claude/rules/tool-evaluation.md` (evaluation principles)
- `.claude/skills/tool-registry/SKILL.md` (registry data access)
- `.claude/skills/tool-eval/SKILL.md` (evaluation process)
- `@reference/tool-evaluation-criteria.md` (evaluation framework)
- `@reference/tool-evaluation-playbook.md` (install discovery process)
- `reference/evaluations/` (evaluation research)
- `scripts/setup-*.sh/.ps1` (per-tool setup scripts)

## Cross-References

- Framework registry: `/frameworks` skill
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Governed data access: `@.claude/rules/governed-data-access.md`
