# Incident Governance

**Intent**: **Purpose**: Document the framework for tracking and
resolving harness deficiencies through structured defect management.
**Scope**: What incident governance is based on, why we track incidents
this way, how it's maintained, and how it fits the three-layer model.
NOT the operational filing process (that's in
`@.claude/rules/incident-governance.md`). NOT the incident data itself
(that's in `@registries/incidents.json`). **Audience**: Agents
encountering the incident system for the first time, framework
adoption work.

## Source Discipline

Quality management — defect tracking and continuous improvement
(PDCA: Plan-Do-Check-Act). Incidents are defects in the harness. The
severity classification, lifecycle (open → planned → closed), and
staleness rules mirror defect tracking practices.

## How We Adopted It

- **Defect tracking** → `@registries/incidents.json` with structured
  fields, severity classification, lifecycle states
- **Continuous improvement** → surfacing duty (every session looks for
  ambiguities), staleness rule (90 days without a plan = stale)
- **Classification** → decision tree distinguishing incidents where
  code deviates from spec from those where no spec exists
- **Enriched context** → discovery-to-continuation cycle captures why
  an incident was filed, not just what's wrong. See
  `@reference/framework-adoption.md`.

## How It's Maintained

- `/incident` skill files new entries (model-invocable)
- `/audit` skill checks health: sequential IDs, required fields,
  staleness, duplicate detection
- Incident schema defined in `@.claude/rules/incident-governance.md` —
  schema changes are protected file amendments
- Framework-level incidents get per-entry reference files
  (`reference/incident-*.md`)

## Implementing Artifacts

- `@.claude/rules/incident-governance.md` (operational rule)
- `@registries/incidents.json` (data)
- `@.claude/skills/incident/SKILL.md` (filing)
- `@.claude/skills/audit/SKILL.md` (health checking)

## Cross-References

- Framework registry: `@registries/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Discovery cycle: `@reference/framework-adoption.md`
