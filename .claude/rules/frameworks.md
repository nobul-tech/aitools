## Frameworks (this repo)

**Intent**: **Purpose**: State what frameworks are, when to check
them, and where the registries live — so agents always know to check
before assuming. **Scope**: Framework concept, registry references,
and harness registry list. NOT framework data (use `/frameworks` skill). NOT the adoption process (see
`@reference/framework-adoption.md`). **Audience**: Every agent,
every session.

Frameworks are governance structures adopted from established
disciplines into the harness. Each bridges a discipline's concepts
to concrete harness artifacts (rules, skills, hooks, reference files).

When an agent encounters a decision point without explicit guidance,
check whether an existing framework addresses it before assuming.
The assumption is the failure mode — see
`@reference/framework-adoption.md` for the discovery-to-continuation
cycle.

### Framework registry

The framework registry (accessible via `/frameworks` skill) is the source of truth for all
adopted frameworks. Each entry includes: name, what it governs,
source discipline, key concepts, reference file, and implementing
artifacts.

### Harness registries

Each registry follows the three-layer pattern defined in
`@reference/framework-three-layer-governance.md` "Registry Convention":
rule (intent, always in context) + JSON (data, source of truth) +
skill (access layer).

| Registry | Rule | Data | Write Skill | Read Skill |
|----------|------|------|-------------|------------|
| Frameworks | This file | `@reference/framework-registry.json` | — | `/frameworks` |
| Gaps | `@.claude/rules/gap-governance.md` | `@reference/known-gaps.json` | `/gap` | `/gaps` |
| Tools | `@.claude/rules/tool-lifecycle.md` | `reference/tool-registry.json` | `/tool-eval` | `/tools` |

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
