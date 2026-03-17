## Frameworks (this repo)

**Intent**: **Purpose**: Govern how the harness grows — ensuring
agents check existing frameworks before assuming, and that new
frameworks follow the adoption lifecycle. **Scope**: The governing
principle (check before assuming), the three-layer registry pattern,
trigger directive for `/frameworks` skill. NOT framework data
(use `/frameworks` skill — it gates `reference/framework-registry.json`).
NOT the adoption process (`reference/framework-adoption.md`). NOT
individual framework documentation (`reference/framework-*.md`).
NOT the provenance map (use `/frameworks` skill).
**Audience**: Every agent, every session.

### Governing principle

When an agent encounters a decision point without explicit guidance,
check whether an existing framework addresses it before assuming.
The assumption is the failure mode. Invoke the `/frameworks` skill
to check coverage.

### Three-layer registry pattern

Every governed registry follows: rule (governance, always in context)
+ JSON (data, source of truth) + skill (access layer). The rule
states the intent and trigger. The JSON holds the state. The skill
gates access to the JSON — agents read and write data through the
skill, never directly.

Registries and their governing skills are documented in the framework
registry itself (`reference/framework-registry.json` via `/frameworks`
skill). Do not duplicate that inventory here — this rule governs the
pattern, not the instances.

### When to invoke /frameworks

Invoke the `/frameworks` skill when ANY of these arise:

- Checking if a framework exists for a domain or decision point
- Looking up a framework's implementing artifacts
- Checking the provenance of an adapted concept
- Adding a newly adopted framework to the registry
- Discussing which discipline governs a class of decisions
- User asks about frameworks or says /frameworks

The skill provides the governed process for reading and writing the
framework registry. Accessing the registry JSON directly bypasses
that process.

### Cross-references

- Framework registry data: `/frameworks` skill
- Adoption lifecycle: `@reference/framework-adoption.md`
- Three-layer pattern: `@reference/framework-three-layer-governance.md`
- Governed data access: `@.claude/rules/governed-data-access.md`
- Provenance map: `/frameworks` skill (check provenance mode)
