## Frameworks (this repo)

**Intent**: **Purpose**: Govern the harness registry pattern and the
framework adoption process — ensuring agents check existing governance
before assuming, and all governed data follows the three-layer pattern.
**Scope**: Registry of registries, framework governance principle, and
skill gate. NOT framework data or lookup (use `/frameworks` skill).
NOT the adoption process (see `/frameworks` skill for entry point).
**Audience**: Every agent, every session.

### Governing principle

When an agent encounters a decision point without explicit guidance,
check whether an existing framework addresses it before assuming.
The assumption is the failure mode. Invoke the `/frameworks` skill
to check coverage.

### Harness registries

Each registry follows the three-layer pattern defined in
`@reference/framework-three-layer-governance.md` "Registry Convention":
rule (intent, always in context) + JSON (data, source of truth) +
skill (access layer).

| Registry | Rule | Data | Process Skill | Data Skill |
|----------|------|------|---------------|------------|
| Frameworks | This file | `@reference/framework-registry.json` | — | `/frameworks` |
| Incidents | `@.claude/rules/incident-governance.md` | `@reference/incidents.json` | `/incident` | `/incident` |
| Glossary | `@.claude/rules/glossary.md` | `@reference/glossary.json` | — | `/glossary` |
| Tool registry | `@.claude/rules/tool-lifecycle.md` | `@reference/tool-registry.json` | — | `/tool-registry` |
| Tool evaluation | `@.claude/rules/tool-evaluation.md` | `reference/evaluations/` | `/tool-eval` | — |
| Artifact harvesting | `@.claude/rules/artifact-harvesting.md` | `harvesting/` | `/harvest` | `/harvest` |
| Tool operations | `@.claude/rules/tool-ops.md` | `@reference/tool-ops.json` | — | `/tool-ops` |

### When to invoke /frameworks

Invoke the `/frameworks` skill when ANY of these arise:

- Checking if a framework exists for a domain or decision point
- Looking up a framework's implementing artifacts
- Adding a newly adopted framework to the registry
- Discussing which discipline governs a class of decisions
- User asks about frameworks or says /frameworks

The skill provides the governed process for reading and writing the
framework registry. Accessing the registry JSON directly bypasses
that process.
