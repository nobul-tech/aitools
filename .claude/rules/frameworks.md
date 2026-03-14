## Frameworks (this repo)

Frameworks are governance structures adopted from established
disciplines into the harness. Each bridges a discipline's concepts
to concrete harness artifacts (rules, skills, hooks, reference files).

When an agent encounters a decision point without explicit guidance,
check whether an existing framework addresses it before assuming.
The assumption is the failure mode — see
`@reference/framework-adoption.md` for the discovery-to-continuation
cycle.

### Framework registry

The framework registry (`@reference/framework-registry.json`,
accessible via `/frameworks` skill) is the source of truth for all
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
