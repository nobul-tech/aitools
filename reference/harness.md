# Harness

The harness is aitools and the tools, context, state, artifacts,
frameworks, and provenance it manages for aitools users working on
any project on any platform, including aitools developers who are
themselves users working on both aitools and other projects.

**Intent**: **Purpose**: Define the harness, its components, and how
they relate. **Scope**: Architecture and component definitions only.
NOT artifact roles — what each artifact type is for and what it must
not contain (see `/artifact-roles` skill). NOT how to adopt new
frameworks (`@reference/framework-adoption.md`). NOT operational
guides for any specific component (see implementing artifacts).
**Audience**: Any agent working within the harness, framework
adoption work, `/audit` skill.

## Components

**Platform** — Claude Code provides the infrastructure: CLAUDE.md
(5-level hierarchy), rules, skills, hooks, settings, commands, agents,
session management. Full capability set documented upstream. Our
reference files track what we depend on and what's available but not
yet adopted (`@reference/tool-ops-claude-code.md`).

**Configuration** — our use of the platform. The rules we write,
skills we build, hooks we configure, claude content we author,
settings we set. Exists at two deployment scopes:
- Project (`.claude/rules/`, `.claude/skills/`, `.claude/commands/`,
  project claude) — conventions for this repo
- User (`~/.claude/rules/`, `~/.claude/skills/`, `~/.claude/hooks/`,
  user claude, user settings) — preferences and governance that
  follow the developer across all projects

**Orchestration** — aitools manages the full lifecycle of harness
content: authoring, building, deploying, and maintaining configuration
across machines and users. This includes:
- Sourcing harness context from `shared/` (templates, hooks, skills,
  shell aliases) and dotprofile repos (`@reference/user-repo.md`)
- Resolving priority between shared templates and user customizations
  (dotprofile wins; shared is fallback and MDM source)
- Interactive deployment review with adoption/merge logic
  (`@reference/managed-file-deployment.md`)
- Build pipeline generating self-contained deploy scripts
  (`@.claude/rules/git-safety.md`)
- Setup scripts, shared libraries, entry points, verification
  checklists, AI-assisted operations, incident tracking (via
  `/incident` skill), plans, and reference files

See `@CLAUDE.md` for the full project description.

**Managed tools** — CLI tools, dependencies, and build tools governed
by `/tool-registry` skill. Each gets setup scripts, platform lifecycle
tracking, and operational metadata (via `/tool-ops` skill). Standing
orders and hooks enforce tool selection. See
`@.claude/rules/tool-lifecycle.md` for the onboarding process.

**Frameworks** — governance structures built by adopting concepts from
established disciplines. Each bridges a discipline and the harness
artifacts that implement it. Discipline → framework → artifacts. A gap
in a framework means an entire class of decisions has no governing
structure. A gap in an artifact means the framework exists but a
specific implementation is missing or broken. The framework registry
is governed by `/frameworks` skill. Individual framework documentation
lives in `reference/framework-*.md` files. See
`@.claude/rules/frameworks.md` for the rule.

**Provenance** — every piece of operational learning, every decision,
every work product has provenance: what it was based on, when, by whom,
and whether the basis has been superseded. The provenance component
tracks dependency chains between knowledge items, propagates
invalidation when assumptions are falsified, records known
contradictions (nogood sets) to prevent rediscovery of dead ends, and
maintains temporal validity windows so stale knowledge is surfaced
before it causes harm. Provenance is not a feature layered on top of
the other five components — it is the connective tissue that makes
the harness a knowledge system rather than a configuration manager.
See `@reference/framework-provenance.md` for the discipline source
and adoption rationale.

## How the Components Relate

The six components form a dependency chain:

```
Platform (external, provided by Claude Code)
    -> Configuration (our use of the platform)
        -> Orchestration (manages configuration lifecycle)
            -> Managed Tools (governed by orchestration)
            -> Frameworks (governing structures for decisions)
            -> Provenance (tracks what everything is based on)
```

Provenance cuts across the other components: it tracks the basis for
configuration decisions, the history of orchestration changes, the
evaluation chain for tool selections, and the adoption rationale for
frameworks. It is both a component (with its own tables, schema, and
processing) and a cross-cutting concern (every other component
produces provenance data).

## Cross-References

- Glossary definition: `/glossary` skill (term: harness)
- How the harness grows: `@reference/framework-adoption.md`
- Artifact roles: `/artifact-roles` skill
- Governed vocabulary: `@reference/framework-governed-vocabulary.md`
- Registry convention: `@reference/framework-three-layer-governance.md`
- Framework rule: `@.claude/rules/frameworks.md`
- Project description: `@CLAUDE.md`
- Provenance framework: `@reference/framework-provenance.md`
- Skills: `/frameworks`, `/glossary`, `/audit`, `/intent-audit`, `/incident`
