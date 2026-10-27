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

**Environment** — the agent runtime the harness runs in (Claude Code
locally on a platform, or a hosted service such as Claude Code web or
Cursor cloud; supported list: `@reference/cross-platform-detail.md`
"Supported platforms and environments")
provides the infrastructure: CLAUDE.md
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
- Package build generating installable packages for a fleet (the
  package path, `build-package`: Windows `.intunewin`, macOS `.pkg`,
  Linux `.deb`), a distribution parallel to the dev and MDM paths that
  runs the same `scripts/` from a payload of the aitools tree
  (`@plans/build-package/design.md`)
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
Environment (external, e.g. Claude Code)
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

## Deployed harness (`~/.aitools`)

`scripts/deploy-harness.sh` / `.ps1` builds the deployed harness in
`~/.aitools` (Windows `%USERPROFILE%\.aitools`) from the repos. Every
file goes through `deploy_managed_file()` in `@scripts/aitools-lib.sh` /
`Deploy-ManagedFile` in `@scripts/aitools-lib.ps1`, with the summary tool
name `harness files` and the repo file it came from as the adopt target.
`config.json` is generated from `profile.json` by calling the only config
writer, `scripts/setup-user-config.sh` / `.ps1`.

| Deployed to | Sources, in order | Layout | Conflict unit |
|-------------|-------------------|--------|---------------|
| `reference/` | `reference/` | tree (relative paths kept) | none (one source) |
| `registries/` | `registries/` | tree | none (one source) |
| `hooks/` | `shared/hooks/`, `.claude/hooks/` | flat (top-level files) | file name |
| `skills/` | `shared/skills/`, `.claude/skills/` | one directory per skill | skill directory name |
| `rules/` | `shared/rules/`, `.claude/rules/`, `<dotprofile>/claude/rules/` | flat (top-level `*.md`) | file name |
| `bin/` | `scripts/harness-db.py`, `read-session.py`, `read-session-full.py` | flat | none (fixed list) |

### Conflict handling

- **First source wins.** Sources are read in the order above. The first
  source that has a unit (a file name for rules and hooks, a directory
  name for skills) deploys it; the same unit in a later source is
  skipped.
- **Each skipped duplicate is an error**: `log_error` naming both
  sources, plus one ERROR row under `harness files`. The run continues
  and exits 1. The duplicate stays an error on every run until it is
  renamed or removed in one of the sources.
- **Case-insensitive.** Names that differ only in case are duplicates
  (the macOS and Windows file systems are case-insensitive).
- **Skills are whole directories.** The winning source's skill directory
  is deployed as it is; files are never merged from two sources.

### Assumptions and what is not detected

- **Git-tracked files only**, in every source (`git ls-files`). Untracked
  and ignored files, including the `*.bak.*` backups an adopt leaves in
  the repo, are never deployed. A source directory outside a git work
  tree is an error and is skipped. A missing source directory (for
  example `.claude/hooks/`) is logged as info.
- **`*.bak.*` names are never deployed**, even when tracked: that is the
  library's backup naming (`backup_file()`).
- **Nested files in a flat source** (rules, hooks), non-`.md` files in a
  rules source, and files outside a skill directory are skipped with a
  detail log line; they are not reported as conflicts.
- **Order, not content, picks the winner.** Two copies with identical
  content are still a duplicate; a later copy is never preferred because
  it is newer.
- **Not detected**: the same content under two different names; a name
  shared across kinds (a skill and a rule both called `scratch`, which
  land in different directories); conflicts with files already in a
  tool's own location (`~/.claude/rules/`), which the fan-out in
  `setup-user-claude` / `setup-user-cursor` handles.
- **No deletion.** A file in `~/.aitools` with no source (a renamed or
  removed source, a file the user added) is preserved and logged on
  every run.
- **Backups live next to deployed files** (`<file>.bak.<timestamp>`, by
  the library). Anything that copies out of `~/.aitools` skips `*.bak.*`.
- **Trailing newlines are normalized**: a deployed copy ends with exactly
  one newline.
- **Adopt** writes the winning source file only. Adopting into a file in
  its repo's protected-files table (`@.claude/rules/sources-of-truth.md`)
  logs a WARN naming the file; the library never commits or pushes.

## Cross-References

- Glossary definition: `/glossary` skill (term: harness)
- How the harness grows: `@reference/framework-adoption.md`
- Artifact roles: `/artifact-roles` skill
- Governed vocabulary: `@reference/framework-governed-vocabulary.md`
- Registry convention: `@reference/framework-three-layer-governance.md`
- Framework rule: `@.claude/rules/frameworks.md`
- Project description: `@CLAUDE.md`
- Provenance framework: `@reference/framework-provenance.md`
- Deployed harness: `@scripts/deploy-harness.sh` / `.ps1`;
  managed-file model: `@reference/managed-file-deployment.md`
- Rules, their scopes and the rules fan-out: `@reference/rules.md`
- Skills: `/frameworks`, `/glossary`, `/audit`, `/intent-audit`, `/incident`
