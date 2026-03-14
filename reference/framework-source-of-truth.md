# Source-of-Truth Protection

**Intent**: **Purpose**: Document the framework for protecting critical
files that propagate across machines and affect real workflows.
**Scope**: What change management principles we adopted and why. NOT
the list of protected files or the review process (those are in
`@.claude/rules/sources-of-truth.md`). **Audience**: Agents
encountering the protection gate, framework adoption work.

## Source Discipline

Change management — change advisory boards and approval gates.
Critical changes require review before they take effect. The cost of
pausing to review is low; the cost of a bad change propagating to all
machines is high.

## How We Adopted It

- **Approval gate** → draft, present, wait for approval before writing
- **Protected file registry** → table of files that feed downstream
  scripts and deployments
- **Intent protection** → intent statements shape how all future
  sessions interpret files, so they require the same gate
- **Exceptions** → trivial fixes and user-dictated content bypass the
  gate (low risk, high friction to review)

## How It's Maintained

- New protected files added to the table as they're created
- Intent statements added to the protection scope
- `/audit` skill can verify protected files haven't been modified
  without review

## Implementing Artifacts

- `@.claude/rules/sources-of-truth.md` (operational rule)

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
- Intent documentation: `/intent-writing` and `/intent-audit` skills
