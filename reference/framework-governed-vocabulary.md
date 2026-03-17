# Governed Vocabulary

**Intent**: **Purpose**: Document the framework for maintaining
consistent terminology across the harness — how terms are defined,
how they compose, and how the glossary is maintained. **Scope**: The
composition convention, glossary maintenance process, and source
disciplines. NOT the word list (that's in
`@.claude/rules/glossary.md`). NOT the definitions (the `/glossary` skill
gates access to the definitions registry). NOT the registry convention (that's in
`@reference/framework-three-layer-governance.md`). NOT the
cross-reference convention (that's in
`@reference/framework-adoption.md`). **Audience**: Agents adding new
terms, agents resolving terminology ambiguities, framework adoption
work.

## Source Disciplines

- **Ubiquitous language** (Eric Evans, Domain-Driven Design) — every
  term used across the system has one definition, in one place. All
  participants use the same vocabulary. The glossary is the governance
  mechanism.
- **Faceted classification** (S.R. Ranganathan) — terms decompose
  into independent facets that compose together. Don't enumerate every
  combination — define base terms and modifiers, let them compose.

## How We Adopted It

- **Single source of truth** → the `/glossary` skill gates access to
  the definitions registry. No other file redefines a governed term.
- **Always in context** → `@.claude/rules/glossary.md` lists every
  governed term so agents see them every session without loading a
  skill or reading a reference file.
- **Faceted composition** → base artifacts compose with scope modifiers
  instead of enumerating every combination (see convention below).

## Composition Convention

Base artifacts combine with scope modifiers:
`<modifier> <artifact>` = specific harness artifact.

### Scope modifiers

| Modifier | Meaning |
|----------|---------|
| project | In the aitools repo, for this repo's sessions |
| shared | In `shared/` in the aitools repo, source for deployment |
| dotprofile | In the user's `aitools-<username>` repo, personal source |
| user | Deployed to `~/`, active on the machine |

### Base artifacts

| Artifact | What it is |
|----------|-----------|
| alias | Shell alias file (`shared/shell/` or deployed to profile) |
| claude | CLAUDE.md file at the given scope |
| config | JSON configuration file (settings.json, config.json, mcp.json) |
| hook | Hook script (`.sh` in `shared/hooks/` or `~/.claude/hooks/`) |
| rule | Claude Code rule file (`.md` in `.claude/rules/` or `~/.claude/rules/`) |
| skill | Skill definition (`SKILL.md` in `.claude/skills/`, `shared/skills/`, or `~/.claude/skills/`) |

### Examples

| Composed term | Resolves to |
|---------------|-------------|
| project claude | `CLAUDE.md` in aitools repo root |
| shared claude | `shared/claude-shared.md` |
| dotprofile claude | `<userRepoPath>/claude/CLAUDE.md` |
| user claude | `~/.claude/CLAUDE.md` (generated, don't edit directly) |
| project rule | `.claude/rules/*.md` |
| user rule | `~/.claude/rules/*.md` |
| shared skill | `shared/skills/*/SKILL.md` (source) |
| user skill | `~/.claude/skills/*/SKILL.md` (deployed) |
| shared hook | `shared/hooks/*.sh` (source) |
| user hook | `~/.claude/hooks/*.sh` (deployed) |
| user config | `~/.claude/settings.json` |

## Glossary Maintenance

- New terms are added via `/glossary` skill which reads the current
  JSON, formats the new entry with all required fields, presents for
  review (protected file per `@.claude/rules/sources-of-truth.md`),
  and writes if approved
- The glossary rule must be updated in the same operation — a term
  in the JSON without a corresponding line in the rule is invisible
  to agents
- Both files are protected — changes require user approval
- `/audit` skill scope includes: terms used without glossary
  definition, definitions that contradict the glossary, composed
  terms using undefined modifiers or artifacts
- When a term is ambiguous (like "scope" was), split into specific
  governed terms and remove the ambiguous standalone

## Implementing Artifacts

- `@.claude/rules/glossary.md` (word list, always in context)
- `/glossary` skill (gate to definitions, source of truth)
- `/glossary` skill (read definitions, add new terms)

## Cross-References

- Framework registry: `/frameworks` skill
- Framework adoption: `@reference/framework-adoption.md`
- Harness definition: `@reference/harness.md`
