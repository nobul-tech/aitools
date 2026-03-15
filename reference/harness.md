# Harness

**Intent**: **Purpose**: Define the five components of the harness
and what each contains. **Scope**: Architecture only — what the
components are, where they live, how they relate. NOT how to adopt
new frameworks (see `@reference/framework-adoption.md`). NOT
operational guides for any specific component (see the implementing
artifacts linked below). **Audience**: Any agent working within the
harness, framework adoption work, `/audit` skill.

## Components

**Platform** — Claude Code provides the infrastructure: CLAUDE.md
(5-level hierarchy), rules, skills, hooks, settings, commands, agents,
session management. Full capability set documented upstream
(https://docs.anthropic.com/en/docs/claude-code,
https://github.com/anthropics/claude-code). Our reference files track
what we depend on and what's available but not yet adopted
(`@reference/claude-code-maintenance.md`,
`@reference/claude-code-practices.md`).

**Configuration** — our use of the platform. The rules we write, skills
we build, hooks we configure, claude content we author, settings we
set. Exists at two deployment scopes:
- Project (`.claude/rules/`, `.claude/skills/`, `.claude/commands/`,
  project claude) — conventions for this repo
- User (`~/.claude/rules/`, `~/.claude/skills/`, `~/.claude/hooks/`,
  `~/.claude/settings.json`, user claude) — preferences and governance
  that follow the developer across all projects

**Rule-skill governance**: Within configuration, rules and skills
have a governance relationship. Rules (always loaded) govern domains
and enforce process via trigger directives. Skills (loaded on demand)
implement the governed process. Governed data files (JSON registries)
are accessed through their governing skills — the skill is the API,
the JSON is the implementation detail. See
`@reference/framework-governed-data-access.md`.

**Orchestration** — aitools manages the full lifecycle of harness
content: authoring, building, deploying, and maintaining configuration
across machines and users. This includes:
- Sourcing harness context from `shared/` (templates, hooks, skills,
  shell aliases) and dotprofile repos. See `@reference/user-repo.md`.
- Resolving priority between shared templates and user customizations
  (dotprofile wins; shared is fallback and MDM source). See
  `@reference/claude-code-practices.md` "User-Level CLAUDE.md Setup".
- Interactive deployment review with adoption/merge logic. See
  `@reference/managed-file-deployment.md`.
- Build pipeline generating self-contained deploy scripts. See
  `@.claude/rules/git-safety.md`.
- Setup scripts, shared libraries, entry points, verification
  checklists (`@reference/pre-commit-checklist.md`,
  `@reference/pre-push-checklist.md`,
  `@reference/post-push-checklist.md`), AI-assisted operations
  (`@reference/agentic-framework.md`), gap tracking
  (`@reference/known-gaps.json`), plans, and reference files

See `@CLAUDE.md` for the full project description.

**Managed tools** — CLI tools, dependencies, and build tools governed
by `@reference/tool-registry.md`. Each gets setup scripts, platform
lifecycle tracking, and a corresponding user skill documenting usage
patterns, platform gotchas, and anti-patterns. Standing orders and
hooks enforce tool selection. See `@.claude/rules/tool-lifecycle.md`
for the onboarding process.

**Frameworks** — governance structures built by adopting concepts from
established disciplines. Each bridges a discipline and the harness
artifacts that implement it. Discipline → framework → artifacts. A gap
in a framework means an entire class of decisions has no governing
structure. A gap in an artifact means the framework exists but a
specific implementation is missing or broken. The framework registry
lives in `@reference/framework-registry.json`. Individual framework
documentation lives in `reference/framework-*.md` files. See
`@.claude/rules/frameworks.md` for the rule.

## Cross-References

- Glossary definition: `@reference/glossary.json` (term: harness)
- How the harness grows: `@reference/framework-adoption.md`
- How harness components are organized: `@reference/framework-governed-vocabulary.md`
- Registry convention: `@reference/framework-three-layer-governance.md`
- Cross-reference convention: `@reference/framework-adoption.md`
- Framework registry: `@reference/framework-registry.json`
- Framework rule: `@.claude/rules/frameworks.md`
- Project description: `@CLAUDE.md`
- Skills: `/frameworks`, `/glossary`, `/audit`, `/intent-audit`, `/gap`
