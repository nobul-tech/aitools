# Three-Layer Governance

**Intent**: **Purpose**: Document the organizing principle for all
aitools governance: prevention, detection, and audit as layered
defense. **Scope**: What the layers are, why three, how they interact,
and how new governance capabilities are assigned to layers. NOT the
operational details of any specific layer (those live in the
implementing artifacts). **Audience**: Agents designing new governance
features, the `/audit` skill, framework adoption work.

## Source Discipline

Quality management — layered defense (defense in depth). Each layer
catches what the previous missed. No single layer is expected to be
complete.

## The Three Layers

| Layer | When | Mechanism | Catches |
|-------|------|-----------|---------|
| Prevention | Every session, before issues are created | Rules in context, skills loaded on demand | Stops issues by showing the right way |
| Detection | During tool calls and session events | Hooks firing in real-time | Issues as they happen, blocking or warning |
| Audit | On demand | `/audit` skill, `/incident` skill | What slipped through both layers |

**Rule-skill governance**: Rules govern and enforce process; skills
implement it. Rules are always in context and contain trigger directives
stating WHEN to invoke their corresponding skill. The skill provides
the governed process (loaded on demand). This is the primary enforcement
mechanism in the prevention layer. Hook stderr messages reference skills
to close the detection-to-prevention remediation loop.

A rule without a trigger directive for its skill is a governance gap.
A skill without a corresponding rule trigger is ungoverned process —
it exists but nothing enforces its use. See
`@reference/framework-governed-data-access.md` for the full pattern.

## Layer Assignment

When adding a new governance capability:

- **Can it be taught?** → Prevention (rule or skill)
- **Can it be detected in real-time?** → Detection (hook)
- **Does it require deep analysis?** → Audit (skill with
  `disable-model-invocation: true`)

Most capabilities start as prevention (rule), graduate to detection
(hook) when violations recur, and are verified by audit.

## How It's Maintained

- New rules/skills/hooks are assigned to layers at creation time
- `@.claude/rules/hook-rollout.md` governs how detection hooks
  graduate from observe to enforce
- `/audit` skill verifies all three layers are functioning
- `@plans/governance-and-compliance-framework.md` tracks the
  implementation roadmap

## Registry Convention

The three-layer governance principle extends to how structured data
is organized in the harness. Every registry follows a three-layer
pattern that mirrors the governance layers:

| Governance Layer | Registry Layer | Always available? |
|-----------------|---------------|-------------------|
| Prevention (rules in context) | Rule (intent, always in context) | Yes |
| Audit (on demand) | Skill (access layer, on demand) | On demand |
| — | JSON (source of truth, protected) | On read |

**Rule** (`.claude/rules/<name>.md`) — always in context, states
intent: what the registry is, why it matters, when to check it.
References the JSON and skill. Contains no data that can drift.

**Structured data** (`reference/<name>.json`) — single source of
truth. Protected file. Machine-readable for `/audit` validation.
Schema documented in the rule. Must include `meta.intent` with
purpose, scope, and audience fields.

**Skill** — loads the JSON on demand, presents it with context.
Injected into subagents via SubagentStart cache. Write skills
(`/incident`, `/tool-eval`) file entries. Read skills (`/incidents`,
`/frameworks`, `/tools`) present the registry.

**Per-entry reference files** (`reference/<concept>-*.md`) — when
entries have enough detail to stand alone. Frameworks and tools
warrant per-entry files. Simple incident entries stay in JSON only;
framework-level incidents that went through the full DTCC (steps 4-6)
get a reference file.

### Naming

- Rule: `.claude/rules/<registry-name>.md`
- Data: `reference/<registry-name>.json` or `reference/<name>-registry.json`
- Write skill: `/<singular>` (e.g., `/incident`, `/tool-eval`)
- Read skill: `/<plural>` (e.g., `/incidents`, `/frameworks`, `/tools`)
- Per-entry reference: `reference/<concept>-<name>.md`
  (e.g., `framework-incident-governance.md`, `tool-perl.md`,
  `incident-020-process-discipline.md`)

### Schema

- Every JSON registry has a `meta` object with: `governance` (rule
  path), `intent` (purpose/scope/audience), `lastUpdated`
- Entry schemas are registry-specific, documented in the rule
- Schema changes are protected file amendments
- `/audit` validates: required fields, valid enums, sequential IDs
  where applicable

### Maintenance

- `lastUpdated` in meta updated on every change
- Rule references the skill for access and the JSON for data
- Skill reads the JSON at invocation time (no stale cache)
- `/audit` validates schema compliance and cross-reference integrity
- Write skills validate before writing

### Current registries

The registry list is maintained in `@.claude/rules/frameworks.md`.

## Three-Layer Completeness

Every governance mechanism in the harness should have all three layers.
A mechanism with only prevention is a suggestion. A mechanism with
prevention and detection is enforced. A mechanism with all three is
governed.

### Rule-skill governance (canonical example)

| Layer | Mechanism | What it does |
|-------|-----------|-------------|
| Prevention | Trigger directive in rule | States WHEN to invoke the skill. Always in context. |
| Detection | PreToolUse hook on skill's data files | Fires when agent reads governed data directly, bypassing the skill process. |
| Audit | `/audit` check | Verifies all rules with skills have trigger directives, and all skills with data files have detection hooks. |

A skill without a trigger directive in its governing rule is ungoverned
process — it exists but nothing enforces its use. A rule without a
detection hook has a single point of failure — if the agent ignores the
directive, nothing catches it.

### Access control (strongest enforcement)

Where possible, enforce process by controlling access rather than
advising it. Skills are APIs; governed JSON files are private data.
Three enforcement levels: training (rule says "use skill"),
monitoring (hook fires on access), access control (context removal
prevents access entirely). Agents without the governing context
receive restricted access via context injection — governed data
files are excluded, and a directive explains the observe-and-report
role.

### Framework completeness audit

When adopting or reviewing a framework, verify three-layer coverage:

| Question | If no |
|----------|-------|
| Does the rule contain trigger directives for its skills? | Prevention gap |
| Is there a hook that detects when governed process is bypassed? | Detection gap |
| Does `/audit` verify this framework's completeness? | Audit gap |

## Implementing Artifacts

- `@CLAUDE.md` design principles (defines the model)
- `@.claude/rules/*.md` (prevention layer)
- `@shared/skills/` and `@.claude/skills/` (prevention + audit)
- `@shared/hooks/*.sh` (detection layer)
- `@plans/governance-and-compliance-framework.md` (implementation)

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Meta-framework: `@reference/framework-adoption.md`
- Incident governance: `@reference/framework-incident-governance.md`
