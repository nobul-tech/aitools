# Gap Governance

**Intent**: **Purpose**: Document the framework for tracking and
resolving harness deficiencies through structured defect management.
**Scope**: What gap governance is based on, why we track gaps this
way, how it's maintained, and how it fits the three-layer model. NOT
the operational filing process (that's in
`@.claude/rules/gap-governance.md`). NOT the gap data itself (that's
in `@reference/known-gaps.json`). **Audience**: Agents encountering
the gap system for the first time, framework adoption work.

## Source Discipline

Quality management — defect tracking and continuous improvement
(PDCA: Plan-Do-Check-Act). Gaps are defects in the harness. The
severity classification, lifecycle (open → planned → closed), and
staleness rules mirror defect tracking practices.

## How We Adopted It

- **Defect tracking** → `@reference/known-gaps.json` with structured
  fields, severity classification, lifecycle states
- **Continuous improvement** → surfacing duty (every session looks for
  ambiguities), staleness rule (90 days without a plan = stale)
- **Classification** → decision tree distinguishing gaps (code deviates
  from spec) from ambiguities (no spec exists)
- **Enriched context** → discovery-to-continuation cycle captures why
  a gap was filed, not just what's wrong. See
  `@reference/framework-adoption.md`.

## How It's Maintained

- `/gap` skill files new entries (model-invocable)
- `/audit` skill checks health: sequential IDs, required fields,
  staleness, duplicate detection
- Gap schema defined in `@.claude/rules/gap-governance.md` — schema
  changes are protected file amendments
- Framework-level gaps get per-entry reference files
  (`reference/gap-*.md`)

## Implementing Artifacts

- `@.claude/rules/gap-governance.md` (operational rule)
- `@reference/known-gaps.json` (data)
- `@.claude/skills/gap/SKILL.md` (filing)
- `@.claude/skills/audit/SKILL.md` (health checking)

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Discovery cycle: `@reference/framework-adoption.md`
