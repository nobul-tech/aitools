## Tool Operations Reference Card (this repo)

**Intent**: **Purpose**: Govern when the user-level `/aitool-ops`
reference-card skill is invoked, and define its relationship to the
project-level `/tool-ops` skill. **Scope**: Trigger directive and
skill relationship only. NOT the operational knowledge itself
(`/aitool-ops` skill for read-only lookups, `/tool-ops` skill for
registry writes). NOT the framework documentation
(`reference/framework-tool-ops.md`). **Audience**: Every agent, every
session.

### Skill taxonomy

The tool-ops domain has three tiers:

| Tier | Skill | Scope | Available where |
|------|-------|-------|-----------------|
| Project (full CRUD) | `/tool-ops` | Read and write tool-ops.json | aitools repo only |
| User (portable) | `/aitool-ops` | Read-only reference card | Any repo (deployed to ~/.claude/skills/) |
| Framework | — | `reference/framework-tool-ops.md` | aitools repo only |

- In the aitools repo, `/tool-ops` is the primary skill (full CRUD).
  `/aitool-ops` is also available but redundant here.
- In any other repo, `/aitool-ops` is the only available skill.
  It provides enough operational knowledge for correct behavior
  without needing the aitools repo's source files.

### When to invoke /aitool-ops

Invoke the `/aitool-ops` skill when ANY of these arise **outside
the aitools repo**:

- Checking deny rules (what permission patterns are blocked and why)
- Checking hook behavior (what hooks fire, their events and matchers)
- Checking CC version dependencies (what breaks if CC upgrades)
- Checking doc access methods (chrome-devtools vs WebFetch)
- Checking governance modes (audit vs active per category)
- Checking subagent limitations (cross-repo access, SendMessage gap)
- Checking session management commands
- User asks about tool operations or says `/aitool-ops`

**In the aitools repo**: prefer `/tool-ops` for full registry access.
Use `/aitool-ops` only for quick read-only lookups when you do not
need write access.

### Reference-card pattern

`/aitool-ops` is the first reference-card skill in the harness. The
pattern it establishes:

- **Derived**: Content is extracted from source files at authoring
  time, not generated at build time (future enhancement)
- **Read-only**: No write operations. The skill is a snapshot.
- **Self-contained**: All operational knowledge is embedded in the
  skill file. No external file references required at runtime.
- **Staleness-aware**: Includes a staleness warning directing users
  to run `aitools` to refresh

Future reference-card skills should follow this pattern.

### Cross-references

- Full CRUD skill: `/tool-ops` (project-level, aitools repo)
- User-level skill: `/aitool-ops` (shared/skills/aitool-ops/)
- Governance rule: `.claude/rules/tool-ops.md` (project-level)
- Framework documentation: `reference/framework-tool-ops.md`
- Governed data access pattern: `.claude/rules/governed-data-access.md`
