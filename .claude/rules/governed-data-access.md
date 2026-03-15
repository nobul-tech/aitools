## Governed Data Access (this repo)

**Intent**: **Purpose**: Govern how governed JSON registries are
accessed — skill-gated, never direct. **Scope**: The access
principle and its enforcement. NOT which registries exist (see
`@.claude/rules/frameworks.md` registries table). NOT the framework
theory (`reference/framework-governed-data-access.md`). **Audience**:
Every agent, every session.

### Governing principle

Governed JSON files are accessed ONLY through their governing skill.
Rules, reference files, CLAUDE.md, and documentation reference the
SKILL, never the JSON file path. A JSON path in a non-skill file is
a bypass vector — agents read it and access the file directly,
defeating the skill gate.

### What may reference JSON file paths

- The governing skill's SKILL.md (it needs the path to read the file)
- Programmatic artifacts: scripts, check scripts, tests, hooks, builds
- The JSON file's own `meta` section (self-referential)

### What MUST NOT reference JSON file paths

- `.claude/rules/*.md` — reference the skill instead
- `CLAUDE.md` — reference the skill instead
- `reference/*.md` — reference the skill instead
- `.cursor/rules/*.mdc` — reference the skill instead
- Plans — reference the skill instead

### Enforcement

- **Prevention**: this rule (always in context)
- **Detection**: pre-commit step 16 (capability bypass audit)
- **Scope**: pre-commit checks `.claude/rules/`, `CLAUDE.md`, and
  any `@` referenced files in `CLAUDE.md`

### Cross-references

- Registries table: `@.claude/rules/frameworks.md`
- Framework theory: `reference/framework-governed-data-access.md`
- Pre-commit enforcement: `scripts/check-pre-commit.sh/.ps1` step 16
